<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.1" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns:syiao="http://syiao-mei.hu" 
    xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs"
    xmlns:tei="http://www.tei-c.org/ns/1.0">
    <xsl:output indent="yes"/>
    <xsl:strip-space elements="*"/>

    <xsl:variable name="wordlists" select="collection('../etym/xml?select=*\d+.csv.xml')"/>
    <xsl:variable name="roots" select="doc('../etym/xml/roots.csv.xml')"/>
    <xsl:variable name="filename" select="sort(uri-collection('../etym/xml?select=*.out.xml'))[last()]"/>
    <xsl:variable name="etymlist" select="doc($filename)"/>
    
    <xsl:function name="syiao:words-similar">
        <xsl:param name="a"/>
        <xsl:param name="b"/>
        
        <xsl:variable name="trfrom" select="'ÿíáúéóúýìàùèòỳīāūēōȳîâûêôûŷǐǎǔěǒıəüẏ'"/>
        <xsl:variable name="trto" select="'yiaueouyiaueoyiaueoyiaueouyiaueoieuy'"/>
        
        <xsl:variable name="aword">
            <xsl:value-of select="translate(translate($a, $trfrom, $trto), 'fmdzl', 'wwtsl')"/>
        </xsl:variable>
        
        <xsl:variable name="bval">
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

        <xsl:variable name="etym" select="$etymlist//word[./form/text() = $word/text() 
            and syiao:senses-match(., $entry) ]"/>
        <xsl:message select="$etym"/>

        <xsl:variable name="wordlist" select="$wordlists[.//word[./form/text() = $etym/etym/text() 
            and syiao:senses-match(., $etym) ]]"/>
        
        <xsl:variable name="new-etym" select="$wordlist/word/etym[./text() = $word/text() and 
            $word/sense/cit/text() = ./tei:sense/tei:cit[@xml:lang='hu']/tei:quote]"/>   
        <xsl:variable name="stage"><xsl:value-of select="$wordlist/wordlist/@stage"/></xsl:variable>
        <xsl:variable name="lang"><xsl:value-of select="$wordlist/wordlist/@label"/></xsl:variable>
        <xsl:message select="$stage, $lang"/>
        
        <xsl:sequence select="$entry//tei:etym"/>        
    </xsl:function>
    
    <xsl:template match="/">
        <xsl:result-document href="../tei/syiao-mei.bak.xml">
            <xsl:copy-of select="./*"/>
        </xsl:result-document>
        
        <xsl:result-document href="../tei/syiao-mei2.xml">
            <xsl:apply-templates />
        </xsl:result-document>

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
                        <xsl:copy-of select="./*"/></xsl:copy>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
            <xsl:sequence select="syiao:get-etym(.)"></xsl:sequence>
        </xsl:copy>
    </xsl:template>
    
    
</xsl:stylesheet>