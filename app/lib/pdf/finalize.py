"""Complete Chromium's PDF/UA metadata without rebuilding its structure tree.

Chromium tags accessible DOM content, but leaves decorative paint, aria-hidden
content, and page furniture outside marked-content sequences. Mark those gaps as
artifacts, preserving every existing MCID and its position in the reading order.
Only use this on PDFs generated from the application's semantic HTML by Grover.
"""
import io
import sys
from xml.sax.saxutils import escape

from pypdf import PdfReader, PdfWriter
from pypdf.generic import ArrayObject, BooleanObject, DecodedStreamObject, DictionaryObject, NameObject


def finalize(content):
    reader = PdfReader(io.BytesIO(content))
    writer = PdfWriter(clone_from=reader)
    root = writer.root_object
    if not root.get('/StructTreeRoot') or not root.get('/Lang'):
        raise ValueError('Chromium PDF must have a structure tree and language')
    title = reader.metadata.title
    if not title:
        raise ValueError('Chromium PDF must have a document title')

    preferences = root.setdefault(NameObject('/ViewerPreferences'), DictionaryObject())
    preferences[NameObject('/DisplayDocTitle')] = BooleanObject(True)
    roles = root['/StructTreeRoot'].setdefault(NameObject('/RoleMap'), DictionaryObject())
    # Chrome uses PDF 2.0 emphasis roles in a PDF 1.7 document. PDF/UA-1 uses Span.
    roles[NameObject('/Strong')] = NameObject('/Span')
    roles[NameObject('/Em')] = NameObject('/Span')

    def normalize_lists(element):
        element = element.get_object()
        if not isinstance(element, DictionaryObject):
            return
        kids = element.get('/K', ArrayObject())
        kids = kids if isinstance(kids, ArrayObject) else [kids]
        for child in kids:
            normalize_lists(child)
        if element.get('/S') != '/LI':
            return
        body = [child for child in kids if isinstance(child.get_object(), DictionaryObject)
                and child.get_object().get('/S') != '/Lbl']
        if not body or all(child.get_object().get('/S') == '/LBody' for child in body):
            return
        # Wrap the list item body without changing its content or reading order.
        wrapper = DictionaryObject({NameObject('/Type'): NameObject('/StructElem'),
            NameObject('/S'): NameObject('/LBody'), NameObject('/P'): element.indirect_reference,
            NameObject('/K'): ArrayObject(body)})
        ref = writer._add_object(wrapper)
        for child in body:
            child.get_object()[NameObject('/P')] = ref
        element[NameObject('/K')] = ArrayObject([child for child in kids if child not in body] + [ref])

    normalize_lists(root['/StructTreeRoot'])
    metadata = DecodedStreamObject()
    metadata.update({NameObject('/Type'): NameObject('/Metadata'), NameObject('/Subtype'): NameObject('/XML')})
    metadata.set_data(f'''<x:xmpmeta xmlns:x="adobe:ns:meta/">
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:pdfuaid="http://www.aiim.org/pdfua/ns/id/">
<dc:title><rdf:Alt><rdf:li xml:lang="x-default">{escape(title)}</rdf:li></rdf:Alt></dc:title>
<dc:language><rdf:Bag><rdf:li>{escape(root['/Lang'])}</rdf:li></rdf:Bag></dc:language>
<pdfuaid:part>1</pdfuaid:part>
</rdf:Description></rdf:RDF></x:xmpmeta>'''.encode('utf-8'))
    root[NameObject('/Metadata')] = writer._add_object(metadata)

    for page in writer.pages:
        stream = page.get_contents()
        operations = []
        depth = 0
        artifact_open = False
        for operands, operator in stream.operations:
            if operator in (b'BDC', b'BMC'):
                has_tag = operands[0] == '/Artifact' or (operator == b'BDC' and '/MCID' in operands[1])
                if depth == 0:
                    if has_tag and artifact_open:
                        operations.append(([], b'EMC'))
                        artifact_open = False
                    elif not has_tag and not artifact_open:
                        operations.append(([NameObject('/Artifact')], b'BMC'))
                        artifact_open = True
                depth += 1
            elif operator == b'EMC':
                depth -= 1
                if depth < 0:
                    raise ValueError('Unbalanced marked content in Chromium PDF')
            elif depth == 0 and not artifact_open:
                operations.append(([NameObject('/Artifact')], b'BMC'))
                artifact_open = True
            operations.append((operands, operator))
        if depth:
            raise ValueError('Unbalanced marked content in Chromium PDF')
        if artifact_open:
            operations.append(([], b'EMC'))
        stream.operations = operations
        page.replace_contents(stream)
        page[NameObject('/Tabs')] = NameObject('/S')

    output = io.BytesIO()
    writer.write(output)
    return output.getvalue()


if __name__ == '__main__':
    sys.stdout.buffer.write(finalize(sys.stdin.buffer.read()))
