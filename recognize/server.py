from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from face_recognition_system import IncrementalFaceRecognition
import cv2
import numpy as np
from io import BytesIO
from PIL import Image
import os

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For development only - configure properly in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize the face recognition system
recognizer = IncrementalFaceRecognition(
    dataset_path="dataset_arcface",
    similarity_threshold=0.6,
    confidence_threshold=0.8
)

@app.post("/recognize")
async def recognize_face(file: UploadFile = File(...)):
    try:
        # Read the uploaded image
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            raise HTTPException(status_code=400, detail="Invalid image file")
        
        # Process the image
        faces, _ = recognizer.detect_faces(image)
        
        results = []
        for face_data in faces:
            embedding = face_data['embedding']
            bbox = face_data['bbox']
            confidence = face_data['confidence']
            
            if len(recognizer.known_faces) > 0:
                best_match, similarity = recognizer.find_best_match(embedding)
                
                if similarity > recognizer.similarity_threshold:
                    person_name = best_match
                    match_confidence = similarity
                else:
                    person_name = "unknown"
                    match_confidence = 0.0
            else:
                person_name = "unknown"
                match_confidence = 0.0
            
            results.append({
                "person_name": person_name,
                "confidence": float(match_confidence),
                "bbox": bbox.tolist(),
                "detection_confidence": float(confidence)
            })
        
        return {"results": results}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/stats")
async def get_statistics():
    try:
        stats = recognizer.get_statistics()
        return stats
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)