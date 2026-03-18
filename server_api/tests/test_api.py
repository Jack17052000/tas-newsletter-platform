import httpx
import pytest
import os

def test_health():
    with httpx.Client(base_url="http://127.0.0.1:8000") as client:
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}

def test_generate_pdf():
    payload = {
        "title": "Automated Test Newsletter",
        "content": "This is a test content.\nIt should span multiple lines.\n" * 50
    }
    with httpx.Client(base_url="http://127.0.0.1:8000") as client:
        response = client.post("/generate", json=payload)
        assert response.status_code == 200
        assert response.headers["content-type"] == "application/pdf"
        
        # Save for manual inspection if needed
        with open("test_output.pdf", "wb") as f:
            f.write(response.content)
        
        assert os.path.exists("test_output.pdf")
        assert os.path.getsize("test_output.pdf") > 1000
