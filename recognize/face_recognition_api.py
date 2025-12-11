from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import tempfile
import shutil
import os
from pathlib import Path
from typing import List, Dict, Any

# Import the recognizer from the existing project file
from face_recognition_system import IncrementalFaceRecognition

app = FastAPI(title="Face Recognition API")

# Allow requests from local Flutter dev server (adjust origin as needed)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:53705", "http://localhost:8080", "http://127.0.0.1:53705", "http://localhost:5000", "*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize the recognizer once
print("Initializing Python face recognizer (this may take a while)...")
recognizer = IncrementalFaceRecognition(dataset_path="dataset_arcface")
print("Recognizer ready")


@app.post('/detect')
async def detect_faces(image: UploadFile = File(...)) -> Dict[str, Any]:
    # Save the uploaded file to a temporary location
    try:
        suffix = Path(image.filename).suffix or ".jpg"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp_path = tmp.name
            shutil.copyfileobj(image.file, tmp)
    finally:
        image.file.close()

    try:
        results = recognizer.detect_faces(tmp_path)
        # detect_faces returns (results, image)
        if isinstance(results, tuple) and len(results) == 2:
            faces, _ = results
        else:
            faces = results

        response_faces = []
        for face in faces:
            bbox = face.get('bbox') if isinstance(face, dict) else None
            confidence = face.get('confidence') if isinstance(face, dict) else None
            embedding = None
            person_name = None
            # The recognizer.detect_faces returns raw embeddings; to identify people we need to run process_image or find_best_match
            # For now return bbox and confidence; identification can be performed by calling a separate endpoint if needed
            response_faces.append({
                'bbox': bbox.tolist() if hasattr(bbox, 'tolist') else bbox,
                'confidence': float(confidence) if confidence is not None else None,
            })

        return {'success': True, 'faces': response_faces}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass


@app.get('/status')
async def status():
    return {"ok": True, "known_people": len(recognizer.known_faces)}


if __name__ == '__main__':
    uvicorn.run(app, host='0.0.0.0', port=8000, log_level='info')
