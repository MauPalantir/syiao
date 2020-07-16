require 'logger'
require 'iconv'

module ConlangCompiler
  class EtymologySet
    attr_reader :set_name, :directory

    def initialize(set_name, directory: '.', column: 5)
      @set_name = set_name
      @directory = directory
      @column = column
    end

    def last_output_file
      files('out').last
    end

    def stage_words
      return @stages if defined? @stages

      @stages = Hash.new([])
      files('csv').reduce(0) do |i, file|
        contents = file_contents(file)
        first_line = contents.shift
        abbrev = first_line[/!(\w+)/] ? first_line.match(/!(\w+)/)[1] : "stage #{i}"

        @stages[abbrev] += contents.compact.reject {|w| w['#'] || w.strip.empty? }.collect do |line|
          m = line.match(/^(?<word>[^"]+)(?:\s*"(?<gloss>.+)")?/)
          m[:word].strip # { word: m[:word].strip, gloss: m[:gloss].to_s.strip }
        end

        i+1
      end
      @stages
    end

    def etymologies
      @etymologies ||= file_contents(last_output_file)
                       .each_with_object({}) do |entry, data|
                         next unless entry.match(/(.+\S)\s*\[(.+)\](?:\s*"(.+)")?/)
                         _, outcome, original, gloss = Regexp.last_match.to_a
                         data[original] = { word: outcome, glosses: gloss.to_s.split(/;\s*/) }
                       end
    end

    def files(filetype = '*')
      Dir.glob(File.expand_path(
        File.join(directory, "#{set_name}.*.#{filetype}")
      )).sort
    end

    def file_contents(filename)
      File.open(filename, 'rb', &:read).force_encoding('UTF-8').lines
    end

    def update_word_etymology(row, column)
      DictionaryRow.new(row, column, self).update_word_etymology
    end

    class DictionaryRow
      @logger = Logger.new('etymologies.log', File::WRONLY | File::APPEND)

      def initialize(row, etymology_column, etym_set, logger = nil)
        @column = etymology_column
        @row = row
        @etym_set = etym_set
        @data =  { word: row[0], part: row[1], meaning: row[2] }
      end

      def self.logger
        @logger
      end

      def logger
        self.class.logger
      end

      # A CSV data row
      def update_word_etymology
        return if found_by_word.empty? && found_by_meaning.empty?

        cell_value = nil
        skip_confirm = false
        correct_result_word = nil

        if found_by_word.size == 1
          original_word = found_by_word.keys.shift
          skip_confirm = true
        elsif found_by_word.size > 1 && found_by_meaning.empty?
          closest_meaning = homonyms_closest_by_meaning
          return if closest_meaning.empty?
          original_word = closest_meaning.first[0]
        else
          if found_by_meaning.size > 1
            closest_word_form = synonyms_closest_by_word_form
            return if closest_word_form.empty?
            original_word = closest_word_form.first[0]
          else
            original_word = found_by_meaning.keys.shift
          end

          resulting_word = etym_set.etymologies[original_word][:word]

          unless row[@column].to_s['~'] || row[0][resulting_word]
            correct_result_word = %w(prop epith name).include?(data[:part]) ? resulting_word.capitalize : resulting_word
          end
        end

        original_stage = etym_set.stage_words.find {|k, v| v.include?(original_word) }
        cell_value ||= "#{original_stage[0]} #{original_word}"

        if correct_result_word
          if confirm_word_update(original_word, correct_result_word, row[7])
            orig_csv = CSV.read("./data/#{row[7]}.csv")
            CSV.open("./data/#{row[7]}.csv", 'wb') do |updated_csv|
              orig_csv.each_with_index do |orig_row, i|
                if orig_row[0] == data[:word]
                  orig_row[0] = correct_result_word
                end
                updated_csv << orig_row
              end
            end
            @row[0] = correct_result_word
          else
            cell_value = "~ #{cell_value}"
          end
        end

        @etym_regexp = Regexp.new("^((?:~ )?(?:#{original_word})|(?:(?:#{etym_set.stage_words.keys.join('|')})? [^#]+))")
        update_etym_cell(cell_value)

        # Update etymology if exact result match is found

        row
      end

      private

      attr_reader :row, :etym_set, :data

      def confirm_word_update(original_word, correct_result_word, original_file)
        # print "#{data[:word]} => #{correct_result_word} \"#{data[:meaning]}\" in #{original_file}"

        # return false
        print "\e[31mFound etym for \e[32;1m#{data[:word]}\e[0m \"#{data[:meaning]}\": \
\e[32;1m#{original_word}. Correct original word to \e[0;1m\"#{correct_result_word}\"?\e[0m"
        result = STDIN.gets.chomp.upcase
        result == 'Y' || result == ''
      end

      def found_by_meaning
        @found_by_meaning ||= etym_set.etymologies.select {|name, etym| etym[:glosses].include?(data[:meaning]) }
      end

      def found_by_word
        @found_by_word ||= etym_set.etymologies.select {|name, etym| etym[:word] == data[:word].downcase }
      end

      # Sort etymologies that yield homophonous result by relevance of meaning.
      #
      # @return Array
      #   [origin, Array(matching words in gloss)]
      def homonyms_closest_by_meaning
        meanings = data[:meaning].split(/[,\.\?;]/)

        found_by_word.reduce([]) do |memo, (word, etym_data)|
          etym_data[:glosses].map { |g| g.split(/[,]/) }.each do |gloss|
            memo << [word, gloss & meanings]
          end
          memo
        end.delete_if {|e| e[1].empty? }.sort_by {|e| e[1].size }.reverse!
      end


      # Return an array sorted by how similar they are.
      #
      # Useful for finding the etymologies for synonyms.
      def synonyms_closest_by_word_form
        consonants = {
          'z' => 's', 'd' => 't', 'g' => 'x'
        }

        transliterated_word = Iconv
          .iconv('ascii//ignore//translit', 'utf-8', data[:word])[0]
          .gsub(/[zdg]/, consonants)
        found_by_meaning.map do |original, etym|
          transliterated_original = Iconv
            .iconv('ascii//ignore//translit', 'utf-8', etym[:word])[0]
            .gsub(/[zdg]/, consonants)
          matching_letters = (transliterated_word.scan(/\w/) & transliterated_original.scan(/\w/))
          [original, matching_letters]
        end.delete_if { |e| e[1].empty? }.sort_by { |e| e[1].size }.reverse!
      end

      def update_etym_cell(cell_value)
        if row[@column].nil? || row[@column].empty?
          @row[@column] = cell_value
        elsif row[@column][@etym_regexp]
          @row[@column] = row[@column].sub(@etym_regexp, cell_value)
        else
          @row[@column] = "#{cell_value} # #{row[@column]}"
        end
        logger.info "Updated #{row[0]} with etymology #{@row[@column]}"
        row
      end
    end
  end
end