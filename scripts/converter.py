#!/usr/bin/env python3

import csv
import os
import re
from lxml import etree
from xml.sax.saxutils import escape
import click
from unidecode import unidecode
from subprocess import check_output
from requests import post
import json
from nltk.stem import WordNetLemmatizer 


class TEI:
    def __init__(self, data):
        self.ns = {'t':'http://www.tei-c.org/ns/1.0'}
        self.data = data
        # self.root = etree.Element('dictionary')
        self.tree = etree.parse('template.xml', etree.XMLParser(remove_blank_text=True))
        self.root = self.tree.getroot()
        extent = self.root.xpath('//t:extent/t:measure', namespaces=self.ns)[0]
        extent.attrib['quantity'] = str(len(self.data))
        extent.text = "{} words".format(len(self.data))
        self.lemmatizer = WordNetLemmatizer() 

    def word2id(self, word):
        return re.sub(r'\W', '', unidecode(word).replace('@', 'e').replace(' ', '_'))

    def pron(self, word, wid):
        path = os.path.dirname(os.path.realpath(__file__))
        out = check_output(['{}/../../espeak-ng/src/espeak-ng --ipa -v sme -w "{}/../wav/{}.wav" "{}"'.format(path, path, wid, word)], shell=True).decode('UTF-8').strip()
        return out.replace('y', 'ɯ')

    def en(self, words):
        url ='https://translation.googleapis.com/v3/projects/syiao-mei:translateText'
        token = check_output(['gcloud auth print-access-token'], shell="true").strip().decode()
        r = post(url, json.dumps({
          "sourceLanguageCode": "hu",
          "targetLanguageCode": "en",
          "contents": words,
          "mimeType": "text/plain"
        }), headers={'Authorization': 'Bearer {}'.format(token), 'Content-Type': 'application/json; charset=utf-8"'})
        return [t['translatedText'] for t in json.loads(r.text)['translations']]

    def translated(self, row):
        translations = list()
        to_trans = [row[2], row[4], row[6]]
        en_keys = list((t for t in to_trans if t != ''))
        en = self.en(en_keys)
        index = 0

        for t in to_trans:
            if t != '': 
                translations.append(en[index])
                index = index + 1
            else:
                translations.append('')

        return translations

    
    def generate_simple(self):
        for n, row in enumerate(self.data):

            word = row[0]
            pos_class = row[1]
            wid = '__'.join([self.word2id(word), pos_class, str(n + 1)])
            entry = etree.Element('entry', attrib={"{http://www.w3.org/XML/1998/namespace}id": wid})

            en = self.translated(list(row))
            
            form = etree.SubElement(entry, 'form')
            form.text = word
            
            pos = etree.SubElement(entry, 'pos')
            pos.text = row[1]

            p=self.pron(re.sub(r'[^\w\s]', '', word), wid)
            pron = etree.SubElement(form, 'pron')
            pron.text = p

            pos = etree.SubElement(entry, 'sense', lang='hu')
            pos.text = row[2]

            pos = etree.SubElement(entry, 'sense',  lang='en')
            pos.text = en[0]

            pos = etree.SubElement(entry, 'root')
            pos.text = row[3]

            pos = etree.SubElement(entry, 'root-sense', lang='hu')
            pos.text = row[4]

            pos = etree.SubElement(entry, 'root-sense',  lang='en')
            pos.text = en[1]

            pos = etree.SubElement(entry, 'etym')
            pos.text = row[5]

            pos = etree.SubElement(entry, 'etym-sense', lang='hu')
            pos.text = row[6]

            pos = etree.SubElement(entry, 'etym-sense',  lang='en')
            pos.text = en[2]

            self.root.append(entry)





    def generate(self):
        n = 0
        for row in self.data:
            n = n+1
            word = row[0]
            print(word)
            pos_class = row[1]
            wid = '__'.join([self.word2id(word), pos_class, str(n)])

            entry = etree.Element('entry', attrib={"{http://www.w3.org/XML/1998/namespace}id": wid})

            form = etree.SubElement(entry, 'form', type='lemma')
            orth = etree.SubElement(form, 'orth')
            orth.text = word

            gramgrp = etree.SubElement(entry, 'gramGrp')
            pos = etree.SubElement(gramgrp, 'pos')
            pos.text = pos_class
            p=self.pron(re.sub(r'[^\w\s]', '', word), wid)
            pron = etree.SubElement(form, 'pron', notation="ipa")
            pron.text = p

            en = self.translated(list(row))

            senses_en = en[0].split(';')

            for i, meaning in enumerate(row[2].split(';')):
                sense = etree.SubElement(entry, 'sense')
                sense_words_en = senses_en[i].split(',')
                print(sense_words_en)

                cit = etree.SubElement(sense, 'cit', type='translation', attrib={"{http://www.w3.org/XML/1998/namespace}lang": "hu"})
                cit_en = etree.SubElement(sense, 'cit', type='translation', attrib={"{http://www.w3.org/XML/1998/namespace}lang": "en"})
    
                for j, sense_word in enumerate(meaning.split(',')):
                    quote = etree.SubElement(cit, 'quote')
                    quote_en = etree.SubElement(cit_en, 'quote')

                    quote.text = sense_word.strip()
                    if (j < len(sense_words_en)):
                        quote_en.text = sense_words_en[j].strip()

            if row[3] != '' or row[5] != '':
                if row[3] != '': 
                    etym = etree.SubElement(entry, 'etym', type="root")
                    etym_lang = etree.SubElement(etym, 'lang')
                    etym_form = etree.SubElement(etym, 'mentioned')
                    
                    etym_lang.text = 'Root'
                    etym_form.text = row[3]
                    if row[4] != '':
                        etym_gloss = etree.SubElement(etym, 'gloss', attrib={"{http://www.w3.org/XML/1998/namespace}lang": "hu"})
                        etym_gloss.text = row[4]

                        etym_gloss_en = etree.SubElement(etym, 'gloss', attrib={"{http://www.w3.org/XML/1998/namespace}lang": "en"})
                        etym_gloss_en.text = ' '.join([self.lemmatizer.lemmatize(w) for w in en[1].split(' ')])

                if row[5] != '':
                    etym = etree.SubElement(entry, 'etym', type="lemma")
                    vals = re.match(r'([A-Z]+) ([\w\s]+\w)', row[5])
                    if vals:
                        etym_lang = etree.SubElement(etym, 'lang')
                        etym_form = etree.SubElement(etym, 'mentioned')
                        
                        etym_lang.text = vals[1]
                        etym_form.text = vals[2]
                if row[6] != '':
                    glossval = re.sub(r'([A-Z]+) ([\w\s]+\w)', '<lang>\\1</lang> <mentioned>\\2</mentioned>', escape(row[6]))
                    glossval_en = re.sub(r'([A-Z]+) ([\w\s]+\w)', '<lang>\\1</lang> <mentioned>\\2</mentioned>', escape(en[2]))
                    string = '<gloss xml:lang="hu">{0}</gloss>'.format(glossval)
                    glossval_elem = etree.fromstring(string)
                    etym.append(glossval_elem)
                    string_en = '<gloss xml:lang="en">{}</gloss>'.format(glossval_en)
                    etym.append(etree.fromstring(string_en))

            self.root.xpath('//t:body', namespaces=self.ns)[0].append(entry)
        return self

    def write(self, output_file):
        self.tree.write(output_file, pretty_print=True, xml_declaration = True, encoding = 'UTF-8')


@click.command()
@click.argument('file')
@click.option('--out', help='Output file', default='tei-dict.xml')
def generate(file, out):
    """Simple program that greets NAME for a total of COUNT times."""
    with open(file + '.csv') as csvfile:
        TEI(list(csv.reader(csvfile, delimiter=',', quotechar='"'))).generate().write(out)


if __name__ == '__main__':
    generate()