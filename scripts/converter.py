#!/usr/bin/env python3

import csv
import os
import re
from lxml import etree
from xml.sax.saxutils import escape
import click
from unidecode import unidecode
from subprocess import check_output

class TEI:
    def __init__(self, data):
        self.ns = {'t':'http://www.tei-c.org/ns/1.0'}
        self.data = data

        self.tree = etree.parse('template.xml', etree.XMLParser(remove_blank_text=True))
        self.root = self.tree.getroot()
        extent = self.root.xpath('//t:extent/t:measure', namespaces=self.ns)[0]
        extent.attrib['quantity'] = str(len(self.data))
        extent.text = "{} words".format(len(self.data))

    def word2id(self, word):
        return re.sub(r'\W', '', unidecode(word).replace('@', 'e').replace(' ', '_'))

    def pron(self, word, wid):
        path = os.path.dirname(os.path.realpath(__file__))
        out = check_output(['{}/../../espeak-ng/src/espeak-ng --ipa -v sme -w "{}/../wav/{}.wav" "{}"'.format(path, path, wid, word)], shell=True).decode('UTF-8').strip()
        return out.replace('y', 'ɯ')


    def generate(self):
        n = 0
        for row in self.data:
            n = n+1
            word = row[0]
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

            for meaning in row[2].split(';'):
                sense = etree.SubElement(entry, 'sense')
                cit = etree.SubElement(sense, 'cit', type='translation', attrib={"{http://www.w3.org/XML/1998/namespace}lang": "hu"})
                translation = etree.SubElement(cit, 'quote')
                translation.text = meaning.strip()

            if row[3] != '' or row[5] != '':
                if row[3] != '': 
                    etym = etree.SubElement(entry, 'etym', type="root")
                    etym_lang = etree.SubElement(etym, 'lang')
                    etym_form = etree.SubElement(etym, 'mentioned')
                    
                    etym_lang.text = 'Root'
                    etym_form.text = row[3]
                    if row[4] != '':
                        etym_gloss = etree.SubElement(etym, 'gloss')
                        etym_gloss.text = row[4]

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
                    string = '<gloss>{0}</gloss>'.format(glossval)
                    glossval_elem = etree.fromstring(string)
                    etym.append(glossval_elem)

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