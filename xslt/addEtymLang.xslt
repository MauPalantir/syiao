<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.1" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns:syiao="http://syiao-mei.hu" 
    xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs xsl tei syiao"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns="http://www.tei-c.org/ns/1.0">
    <xsl:output indent="yes"/>
    <xsl:strip-space elements="*"/>

    <xsl:variable name="wordlists" select="collection('../etym/xml?select=*\d+.csv.xml')"/>
    <xsl:variable name="roots" select="doc('../etym/xml/roots.csv.xml')"/>
    <xsl:variable name="filename" select="sort(uri-collection('../etym/xml?select=*.out.xml'))[last()]"/>
    <xsl:variable name="etymlist" select="doc($filename)"/>
    
    <xsl:function name="syiao:words-similar">
        <xsl:param name="a"/>
        <xsl:param name="b"/>
        
        <xsl:variable name="trfrom" select="'ÿíáúéóúýìàùèòỳīāūēōȳîâûêôûŷǐǎǔěǒẙıǝəüẏ'"/>
        <xsl:variable name="trto"   select="'yiaueouyiaueoyiaueoyiaueouyiaueoyieeuy'"/>
        
        <xsl:variable name="aval">
            <xsl:value-of select="translate(translate(lower-case($a), $trfrom, $trto), 'fmdzlwyaeiou', 'uutslui')"/>
        </xsl:variable>
        
        <xsl:variable name="bval">
            <xsl:value-of select="translate(translate(lower-case($b), $trfrom, $trto), 'fmdzlwyaiioo', 'uutslui')"/>
        </xsl:variable>
        
        <xsl:sequence select="$aval = $bval"/>
    </xsl:function>
    
    <xsl:function name="syiao:senses-match">
        <xsl:param name="a"/>
        <xsl:param name="b"/>
        <xsl:variable name="aval">
            <xsl:choose>
                <xsl:when test="$a/name() = 'entry'">
                    <xsl:value-of select="$a/tei:sense/tei:cit[@xml:lang='hu']/tei:quote"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$a/sense/cit/text()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:variable name="bval">
            <xsl:choose>
                <xsl:when test="$b/name() = 'entry'">
                    <xsl:value-of select="$b/tei:sense/tei:cit[@xml:lang='hu']/tei:quote"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$b/sense/cit/text()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        
        <xsl:sequence select="$aval = $bval"/>
    </xsl:function>
    
    <xsl:function name="syiao:get-etym">
        <xsl:param name="entry"/>
        
        <xsl:variable name="etym" select="$entry/tei:etym[@type='lemma']" />
        <xsl:variable name="root" select="$entry/tei:etym[@type='root']" /> 
        
        <xsl:variable name="word" select="$entry/tei:form/tei:orth"/>

        <xsl:variable name="found-by-word" select="$etymlist//word[./form/text() = lower-case($word/text())]"/>
        <xsl:variable name="found-by-sense" select="$etymlist//word[syiao:senses-match(., $entry) ]"/>
        
        <xsl:variable name="etym">
            <xsl:choose>
                <xsl:when test="count($found-by-word) = 1">
                    <xsl:sequence select="$found-by-word"/>
                </xsl:when>
                <xsl:when test="count($found-by-word) > 1">
                    <xsl:variable name="result-matches">
                        <xsl:for-each select="$found-by-word">
                            <xsl:variable select="." name="res"/>
                            <res>
                                <item><xsl:sequence select="."/></item>
                                <count><xsl:sequence select="count($entry/tei:sense/tei:cit[@xml:lang='hu']/tei:quote[./text() = $res/sense/cit/text()])"/></count>
                            </res>
                        </xsl:for-each>
                    </xsl:variable>
                    <xsl:variable name="sorted">
                        <xsl:perform-sort select="$result-matches/*">
                            <xsl:sort select="./count/text()"/>
                        </xsl:perform-sort>
                    </xsl:variable>
                    <xsl:if test="$sorted[last()]/res/count != 0">
                        <xsl:sequence select="$sorted[last()]//res/item/*"/>
                    </xsl:if>
                </xsl:when>
                <xsl:when test="count($found-by-sense) = 1">
                    <xsl:if test="syiao:words-similar($found-by-sense[1]/form/text(), $entry/form/orth/text())">
                        <xsl:sequence select="$found-by-word[1]"/>
                    </xsl:if>    
                </xsl:when>
                <xsl:when test="count($found-by-sense) > 1">
                    <xsl:variable name="result-matches">
                        <xsl:for-each select="$found-by-sense">
                            <xsl:variable select="." name="res"/>
                            <res>
                                <item><xsl:sequence select="."/></item>
                                <count><xsl:sequence select="count($entry/tei:sense/tei:cit[@xml:lang='hu']/tei:quote[./text() = $res/sense/cit/text()])"/></count>
                            </res>
                        </xsl:for-each>
                    </xsl:variable>
                    <xsl:variable name="sorted">
                        <xsl:perform-sort select="$result-matches/*">
                            <xsl:sort select="./count/text()"/>
                        </xsl:perform-sort>
                    </xsl:variable>
                    <xsl:variable name="similar">
                    <xsl:for-each select="reverse($sorted)/*"> 
                        <xsl:if test="syiao:words-similar(./item/word/form/text(), $entry/tei:form/tei:orth/text())">
                            <xsl:sequence select="./item/*"/>
                        </xsl:if>    
                    </xsl:for-each>
                    </xsl:variable>
                    <xsl:sequence select="$similar"></xsl:sequence>
                </xsl:when>
            </xsl:choose>            
        </xsl:variable>
        

        <xsl:variable name="wordlist" select="$wordlists[.//word[./form/text() = $etym/word/etym/text()
            and syiao:senses-match(., $etym/word) ]]"/>
        
        <xsl:variable name="stage"><xsl:value-of select="$wordlist/wordlist/@stage"/></xsl:variable>
        <xsl:variable name="lang"><xsl:value-of select="$wordlist/wordlist/@label"/></xsl:variable>

        <xsl:for-each select="$entry//tei:etym[@type='root']">
            <xsl:if test="count(./*) > 0">
                <xsl:copy-of select="."/>
            </xsl:if>
        </xsl:for-each> 
        <xsl:choose>
        <xsl:when test="not($etym = '')">
            <etym source="auto" type="lemma">
                <xsl:choose>
                    <xsl:when test="not($etym/word/etym/text() = $entry//tei:etym[@type='lemma']/tei:mentioned/text())">
                        <lang><xsl:value-of select="$lang"/></lang>
                        <mentioned>
                            <xsl:value-of select="$etym/word/etym"/>
                        </mentioned>                        
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:copy-of select="$entry//tei:etym[@type='lemma']/tei:lang"/>
                        <xsl:copy-of select="$entry//tei:etym[@type='lemma']/tei:mentioned"/>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:copy-of select="$entry//tei:etym[@type='lemma']/tei:gloss"/>
            </etym>
        </xsl:when>
            <xsl:otherwise>
                <xsl:if test="count($entry//tei:etym[@type='lemma']/*) > 0">
                    <xsl:copy-of select="$entry//tei:etym[@type='lemma']"/>
                </xsl:if>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:template match="/">
        <xsl:result-document href="../tei/syiao-mei.bak.xml">
            <xsl:copy-of select="./*"/>
        </xsl:result-document>
        

            <xsl:apply-templates />
        

        <xsl:result-document href="../etym/xml/etymologies.xml">
            <xsl:copy select="$etymlist/*">
                <xsl:copy-of select="./@*"/>
                <xsl:for-each select="./*">
                    <xsl:copy select=".">
                        <xsl:variable select="." name="word"></xsl:variable>
                        <xsl:copy-of select="./@*"/>
                        <xsl:value-of select="./text()"/>
                        <xsl:for-each select="./node()">
                            <xsl:copy select=".">
                                <xsl:if test="./name() = 'etym'">
                                    <xsl:variable name="wordlist" select="$wordlists[.//word[$word/etym/text() = ./form/text() and $word/sense/text() = ./sense/text()]]"/>
                                    <xsl:attribute name="stage"><xsl:value-of select="$wordlist/wordlist/@stage"/></xsl:attribute>
                                    <xsl:attribute name="lang"><xsl:value-of select="$wordlist/wordlist/@label"/></xsl:attribute>
                                </xsl:if>
                                <xsl:copy-of select="./*"/>
                                <xsl:value-of select="./text()"/>
                            </xsl:copy>    
                        </xsl:for-each>
                    </xsl:copy>
                </xsl:for-each>
            </xsl:copy>  
        </xsl:result-document>  
    </xsl:template>
    
    <xsl:template match="tei:TEI|tei:text|tei:body">
        <xsl:copy select="."><xsl:apply-templates></xsl:apply-templates></xsl:copy>
    </xsl:template>
    <xsl:template match="tei:teiHeader">
        <xsl:copy-of select="."/>
    </xsl:template>
    
    <xsl:template match="tei:entry">
        <xsl:copy select=".">
            <xsl:copy-of select="@*"/>
            <xsl:for-each select="./*">
                <xsl:choose>
                    <xsl:when test="name() = 'etym'">
                    </xsl:when>
                    <xsl:otherwise>                
                        <xsl:copy>
                            <xsl:copy-of select="@*"/>
                            <xsl:copy-of select="./*"/></xsl:copy>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
            <xsl:sequence select="syiao:get-etym(.)"></xsl:sequence>
        </xsl:copy>
    </xsl:template>
    
    
</xsl:stylesheet>