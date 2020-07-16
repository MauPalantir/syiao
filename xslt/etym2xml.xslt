<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:syiao="http://syiao-mei.hu" xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs">
    <xsl:output indent="yes"/>
    <xsl:strip-space elements="*"/>

     <xsl:function name="syiao:sense">
        <xsl:param name="sense"></xsl:param>
         
         <xsl:for-each select="tokenize($sense, '\s*;\s*')">
             <sense>
                 <xsl:analyze-string select="." regex="^\*\s*(.+)">
                     <xsl:matching-substring>
                         <xsl:attribute name="ana">unattested</xsl:attribute>
                         <xsl:for-each select="tokenize(regex-group(1), '\s*,\s*')">
                             <cit><xsl:value-of select="."/></cit>
                         </xsl:for-each>
                     </xsl:matching-substring>
                     <xsl:non-matching-substring>
                         <xsl:for-each select="tokenize(., '\s*,\s*')">
                             <cit><xsl:value-of select="."/></cit>
                         </xsl:for-each>
                     </xsl:non-matching-substring>
                 </xsl:analyze-string></sense>
         </xsl:for-each>
     </xsl:function>
    
    <xsl:function name="syiao:parse-csv">
        <xsl:param name="basename"></xsl:param>
        <xsl:param name="stage"></xsl:param>
        <xsl:param name="rows"></xsl:param>
    <wordlist xml:id="{$basename}-{$stage}" stage="{$stage}" project="{$basename}">
        <xsl:analyze-string select="$rows[1]" regex="^#\s*!\s*([\w\s]+)$">
            <xsl:matching-substring>
            <xsl:attribute name="label" select="regex-group(1)"></xsl:attribute>
            </xsl:matching-substring>
        </xsl:analyze-string>
               
        <xsl:for-each select="$rows">
            <xsl:analyze-string select="." regex="^([\w\s]+\w)(\s*&quot;(.+)&quot;)*$">
                <xsl:matching-substring>
                <word>
                    <form><xsl:value-of select="regex-group(1)"/></form>
                    <xsl:sequence select="syiao:sense(regex-group(3))"></xsl:sequence>
                </word>                
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:analyze-string select="." regex="^#\s*(.+)$">
                        <xsl:matching-substring>
                            <xsl:comment>
                                <xsl:value-of select="regex-group(1)"/>
                            </xsl:comment>
                        </xsl:matching-substring>
                    </xsl:analyze-string>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:for-each>
        </wordlist>
    </xsl:function>
    
    <xsl:function name="syiao:parse-out">
        <xsl:param name="basename"></xsl:param>
        <xsl:param name="stage"></xsl:param>
        <xsl:param name="rows"></xsl:param>
        <etymology xml:id="{$basename}-{$stage}" stage="{$stage}" project="{$basename}">
            <xsl:for-each select="$rows">
                <xsl:analyze-string select="." regex="^([\w\s]+\w)\s*\[([\w\s]+\w)\s*\](\s*&quot;(.+)&quot;)*$">
                    <xsl:matching-substring>
                        <word>
                            <form><xsl:value-of select="regex-group(1)"/></form>
                            <etym><xsl:value-of select="regex-group(2)"/></etym>
                            <xsl:sequence select="syiao:sense(regex-group(4))"></xsl:sequence>
                        </word>                
                    </xsl:matching-substring>
                    <xsl:non-matching-substring>
                        <xsl:analyze-string select="." regex="^#\s*(.+)$">
                            <xsl:matching-substring>
                                <xsl:comment>
                                <xsl:value-of select="regex-group(1)"/>
                            </xsl:comment>
                            </xsl:matching-substring>
                        </xsl:analyze-string>
                    </xsl:non-matching-substring>
                </xsl:analyze-string>
            </xsl:for-each>
        </etymology>
    </xsl:function>
    

    <xsl:function name="syiao:parse-sc">
        <xsl:param name="basename"></xsl:param>
        <xsl:param name="stage"></xsl:param>
        <xsl:param name="rows"></xsl:param>
        <changes xml:id="{$basename}-{$stage}" stage="{$stage}" project="{$basename}">
            <xsl:for-each select="$rows">
                <xsl:analyze-string select="." regex="^(\w+)\s*=\s*(\w+)(\s*#\s*(.*))?$">
                    <xsl:matching-substring>
                        <category>
                            <name><xsl:value-of select="regex-group(1)"/></name>
                            <sounds><xsl:value-of select="regex-group(2)"/></sounds>
                            <xsl:if test="regex-group(4) != ''"> 
                                <note><xsl:value-of select="regex-group(4)"/></note>
                            </xsl:if>
                        </category>                
                    </xsl:matching-substring>
                    <xsl:non-matching-substring>
                        <xsl:analyze-string select="." regex="^(\w+)\s*\|\s*(\w+)(\s*#\s*(.*))?$">
                            <xsl:matching-substring>
                                <alias>
                                    <source><xsl:value-of select="regex-group(1)"/></source>
                                    <target><xsl:value-of select="regex-group(2)"/></target>
                                    <xsl:if test="regex-group(4) != ''"> 
                                        <note><xsl:value-of select="regex-group(4)"/></note>
                                    </xsl:if>
                                </alias>                
                            </xsl:matching-substring>
                            <xsl:non-matching-substring>
                                <xsl:analyze-string select="." regex="^(\S*)\s*/\s*(\S*)(/(\S*))*(\s*#\s*(.+))?$">
                                    <xsl:matching-substring>
                                        <rule>
                                            <from><xsl:value-of select="regex-group(1)"/></from>
                                            <to><xsl:value-of select="regex-group(2)"/></to>
                                            <context><xsl:value-of select="regex-group(4)"/></context>
                                            <xsl:if test="regex-group(6) != ''">                                            
                                                <note><xsl:value-of select="regex-group(6)"/></note>
                                            </xsl:if>
                                        </rule>                
                                    </xsl:matching-substring>
                                    <xsl:non-matching-substring>
                                        
                                        <xsl:analyze-string select="." regex="^#\s*(.+)$">
                                            <xsl:matching-substring>
                                                <xsl:comment>
                                                <xsl:value-of select="regex-group(1)"/>
                                                </xsl:comment>
                                            </xsl:matching-substring>
                                        </xsl:analyze-string>
                                    </xsl:non-matching-substring>
                                </xsl:analyze-string>
                            </xsl:non-matching-substring>
                        </xsl:analyze-string>
                    </xsl:non-matching-substring>
                </xsl:analyze-string>
            </xsl:for-each>
        </changes>
    </xsl:function>
    
    
    <xsl:template match="/" name="etym2xml">
        <xsl:for-each select="uri-collection('../etym?select=*.*')">
            <xsl:variable name="filename" select="tokenize(., '/')[last()]"/>
            <xsl:variable name="basename" select="tokenize($filename, '\.')[1]"/>
            <xsl:variable name="n" select="tokenize($filename, '\.')[last()-1]"/>
            <xsl:variable name="type" select="tokenize($filename, '\.')[last()]"/>
        
            <xsl:variable name="rows" select="tokenize(.!unparsed-text(.), '\s*\n+\s*')"/>
        
            <xsl:result-document href="../etym/xml/{$filename}.xml">    
                <xsl:choose>
                    <xsl:when test="$type= 'csv'">
                        <xsl:sequence select="syiao:parse-csv($basename, $n, $rows)"/>
                    </xsl:when>
                    <xsl:when test="$type= 'sc'">
                        <xsl:sequence select="syiao:parse-sc($basename, $n, $rows)"/>
                    </xsl:when>
                    <xsl:when test="$type= 'out'">
                        <xsl:sequence select="syiao:parse-out($basename, $n, $rows)"/>
                    </xsl:when>
                </xsl:choose>
            </xsl:result-document>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>