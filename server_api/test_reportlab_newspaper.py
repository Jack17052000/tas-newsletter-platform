from reportlab.platypus import BaseDocTemplate, PageTemplate, Frame, Paragraph
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch

def create_newspaper(filename):
    doc = BaseDocTemplate(filename, pagesize=letter)
    
    # 2 columns layout
    frame1 = Frame(doc.leftMargin, doc.bottomMargin, doc.width/2-6, doc.height, id='col1')
    frame2 = Frame(doc.leftMargin+doc.width/2+6, doc.bottomMargin, doc.width/2-6, doc.height, id='col2')
    
    template = PageTemplate(id='two_columns', frames=[frame1, frame2])
    doc.addPageTemplates([template])
    
    styles = getSampleStyleSheet()
    style = styles['Normal']
    
    story = []
    text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. " * 30
    for i in range(10):
        story.append(Paragraph(f"Paragraph {i}: {text}", style))
        
    doc.build(story)

if __name__ == "__main__":
    create_newspaper("newspaper_test.pdf")
    print("PDF with columns created successfully.")
