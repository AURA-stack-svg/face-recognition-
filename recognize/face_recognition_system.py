import cv2
import numpy as np
import os
import pickle
import json
from datetime import datetime
import insightface
from insightface.app import FaceAnalysis
import sqlite3
from sklearn.metrics.pairwise import cosine_similarity
from pathlib import Path
import shutil
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import matplotlib.patches as patches

class IncrementalFaceRecognition:
    def __init__(self, dataset_path="dataset_arcface", db_path="face_embeddings.db", 
                similarity_threshold=0.6, confidence_threshold=0.8):
        self.dataset_path = Path(dataset_path)
        self.db_path = db_path
        self.similarity_threshold = similarity_threshold
        self.confidence_threshold = confidence_threshold
        
        self.dataset_path.mkdir(exist_ok=True)
        (self.dataset_path / "unknown").mkdir(exist_ok=True)
        
        print("Loading ArcFace model...")
        self.face_app = FaceAnalysis(name='buffalo_l', providers=['CPUExecutionProvider'])
        self.face_app.prepare(ctx_id=0, det_size=(640, 640))
        
        self.init_database()
        self.known_faces = self.load_embeddings_from_db()
        self.processed_images = self.load_processed_images()
        
        print(f"System initialized with {len(self.known_faces)} known faces")
    
    def init_database(self):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS face_embeddings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                person_name TEXT NOT NULL,
                embedding BLOB NOT NULL,
                image_path TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                confidence REAL
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS training_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                image_path TEXT,
                person_name TEXT,
                action TEXT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                confidence REAL
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS processed_images (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                image_path TEXT UNIQUE,
                processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        conn.commit()
        conn.close()
    def load_embeddings_from_db(self):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT person_name, embedding FROM face_embeddings")
        rows = cursor.fetchall()
        known_faces = {}
        for person_name, embedding_blob in rows:
            embedding = np.frombuffer(embedding_blob, dtype=np.float32)
            if person_name not in known_faces:
                known_faces[person_name] = []
            known_faces[person_name].append(embedding)
        conn.close()
        return known_faces
    def load_processed_images(self):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT image_path FROM processed_images")
        rows = cursor.fetchall()
        processed = set()
        for row in rows:
            processed.add(Path(row[0]).name)
        conn.close()
        return processed
    def mark_image_processed(self, image_path):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT OR IGNORE INTO processed_images (image_path)
            VALUES (?)
        ''', (str(image_path),))
        conn.commit()
        conn.close()
        self.processed_images.add(Path(image_path).name)
    def save_embedding_to_db(self, person_name, embedding, image_path, confidence=1.0):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        embedding_blob = embedding.astype(np.float32).tobytes()
        cursor.execute('''
            INSERT INTO face_embeddings (person_name, embedding, image_path, confidence)
            VALUES (?, ?, ?, ?)
        ''', (person_name, embedding_blob, str(image_path), confidence))
        conn.commit()
        conn.close()
    def log_training_action(self, image_path, person_name, action, confidence=1.0):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO training_log (image_path, person_name, action, confidence)
            VALUES (?, ?, ?, ?)
        ''', (str(image_path), person_name, action, confidence))
        conn.commit()
        conn.close()
    
    def detect_faces(self, image_path):
        if isinstance(image_path, str):
            image = cv2.imread(image_path)
        else:
            image = image_path
            
        if image is None:
            print(f"Error: Could not load image")
            return []
        
        faces = self.face_app.get(image)
        
        results = []
        for i, face in enumerate(faces):
            bbox = face.bbox.astype(int)
            embedding = face.embedding
            
            x1, y1, x2, y2 = bbox
            face_img = image[y1:y2, x1:x2]
            results.append({
                'bbox': bbox,
                'embedding': embedding,
                'face_img': face_img,
                'confidence': face.det_score
            })
        
        return results, image
    
    def display_image_with_faces(self, image, faces, image_name):
        plt.figure(figsize=(12, 8))
        
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        plt.imshow(image_rgb)
        
        ax = plt.gca()
        for i, face_data in enumerate(faces):
            bbox = face_data['bbox']
            x1, y1, x2, y2 = bbox
            
            rect = Rectangle((x1, y1), x2-x1, y2-y1, 
                        linewidth=3, edgecolor='red', facecolor='none')
            ax.add_patch(rect)
            
            plt.text(x1, y1-10, f'Face {i+1}', 
                    bbox=dict(boxstyle="round,pad=0.3", facecolor="red", alpha=0.7),
                    fontsize=12, color='white', weight='bold')
        
        plt.title(f'Detected Faces in: {image_name}', fontsize=14, weight='bold')
        plt.axis('off')
        plt.tight_layout()
        plt.show()
    
    def display_individual_faces(self, faces):
        if not faces:
            return
            
        num_faces = len(faces)
        cols = min(4, num_faces)
        rows = (num_faces + cols - 1) // cols
        
        plt.figure(figsize=(4*cols, 4*rows))
        
        for i, face_data in enumerate(faces):
            face_img = face_data['face_img']
            face_img_rgb = cv2.cvtColor(face_img, cv2.COLOR_BGR2RGB)
            
            plt.subplot(rows, cols, i+1)
            plt.imshow(face_img_rgb)
            plt.title(f'Face {i+1}', fontsize=12, weight='bold')
            plt.axis('off')
        
        plt.tight_layout()
        plt.show()
    
    def find_best_match(self, embedding):
        best_match = None
        best_similarity = 0
        
        for person_name, embeddings in self.known_faces.items():
            for stored_embedding in embeddings:
                similarity = cosine_similarity([embedding], [stored_embedding])[0][0]
                if similarity > best_similarity:
                    best_similarity = similarity
                    best_match = person_name
        
        return best_match, best_similarity
    
    def save_face_to_dataset(self, face_img, person_name, image_name):
        person_dir = self.dataset_path / person_name
        person_dir.mkdir(exist_ok=True)
        
        face_path = person_dir / f"{image_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
        cv2.imwrite(str(face_path), face_img)
        return face_path
    
    def add_new_person(self, embedding, face_img, face_index, image_name):
        print(f"\n📸 New face detected - Face {face_index}")
        print("Enter person's name or 's' to skip:")
        person_name = input("Name: ").strip()
        
        if person_name.lower() == 's':
            print(f"⏭️ Skipped Face {face_index}")
            return None
        
        if not person_name:
            person_name = f"unknown_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        face_path = self.save_face_to_dataset(face_img, person_name, f"{image_name}_face{face_index}")
        
        if person_name not in self.known_faces:
            self.known_faces[person_name] = []
        self.known_faces[person_name].append(embedding)
        
        self.save_embedding_to_db(person_name, embedding, face_path)
        self.log_training_action(image_name, person_name, "NEW_PERSON")
        
        print(f"✅ Added {person_name} to the system")
        return person_name
    
    def confirm_match(self, person_name, similarity, embedding, face_img, face_index, image_name):
        print(f"\n🤔 Face {face_index}: I think this is {person_name} (confidence: {similarity:.2f})")
        print("Correct? (y/n/s to skip):")
        
        response = input().strip().lower()
        
        if response == 's':
            print(f"⏭️ Skipped Face {face_index}")
            return None
        elif response in ['y', 'yes']:
            self.known_faces[person_name].append(embedding)
            face_path = self.save_face_to_dataset(face_img, person_name, f"{image_name}_face{face_index}")
            self.save_embedding_to_db(person_name, embedding, face_path, similarity)
            self.log_training_action(image_name, person_name, "CONFIRMED", similarity)
            print(f"✅ Confirmed as {person_name}")
            return person_name
        else:
            print(f"Who is Face {face_index}? (or 's' to skip):")
            correct_name = input("Name: ").strip()
            
            if correct_name.lower() == 's':
                print(f"⏭️ Skipped Face {face_index}")
                return None
            
            if not correct_name:
                correct_name = f"unknown_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            
            if correct_name not in self.known_faces:
                self.known_faces[correct_name] = []
            self.known_faces[correct_name].append(embedding)
            
            face_path = self.save_face_to_dataset(face_img, correct_name, f"{image_name}_face{face_index}")
            self.save_embedding_to_db(correct_name, embedding, face_path)
            self.log_training_action(image_name, correct_name, "CORRECTED")
            
            print(f"✅ Added as {correct_name}")
            return correct_name
    
    def process_image(self, image_path, show_images=True):
        print(f"\n🔍 Processing: {Path(image_path).name}")
        
        faces, original_image = self.detect_faces(image_path)
        
        if not faces:
            print("❌ No faces detected in this image")
            return []
        
        print(f"Found {len(faces)} face(s) in the image")
        
        if show_images:
            self.display_image_with_faces(original_image, faces, Path(image_path).name)
            self.display_individual_faces(faces)
        
        results = []
        image_name = Path(image_path).stem
        
        for i, face_data in enumerate(faces):
            embedding = face_data['embedding']
            face_img = face_data['face_img']
            bbox = face_data['bbox']
            
            print(f"\n👤 Processing Face {i+1}/{len(faces)}")
            
            if len(self.known_faces) == 0:
                person_name = self.add_new_person(embedding, face_img, i+1, image_name)
            else:
                best_match, similarity = self.find_best_match(embedding)
                
                if similarity > self.similarity_threshold:
                    if similarity > self.confidence_threshold:
                        self.known_faces[best_match].append(embedding)
                        face_path = self.save_face_to_dataset(face_img, best_match, f"{image_name}_face{i+1}")
                        self.save_embedding_to_db(best_match, embedding, face_path, similarity)
                        self.log_training_action(image_path, best_match, "AUTO_CONFIRMED", similarity)
                        print(f"✅ Face {i+1}: Auto-confirmed as {best_match} (confidence: {similarity:.2f})")
                        person_name = best_match
                    else:
                        person_name = self.confirm_match(best_match, similarity, embedding, 
                                                    face_img, i+1, image_name)
                else:
                    person_name = self.add_new_person(embedding, face_img, i+1, image_name)
            
            if person_name:
                results.append({
                    'person_name': person_name,
                    'bbox': bbox,
                    'confidence': similarity if 'similarity' in locals() else 1.0
                })
        
        return results
    
    def train_on_dataset(self, dataset_folder, show_images=True):
        dataset_folder = Path(dataset_folder)
        
        if not dataset_folder.exists():
            print(f"❌ Dataset folder {dataset_folder} does not exist")
            return
        
        image_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff'}
        image_files = []
        
        for ext in image_extensions:
            image_files.extend(dataset_folder.glob(f"*{ext}"))
            image_files.extend(dataset_folder.glob(f"*{ext.upper()}"))
        
        if not image_files:
            print("❌ No image files found in the dataset folder")
            return
        
        unprocessed_files = [f for f in image_files if f.name not in self.processed_images]
        
        if not unprocessed_files:
            print("✅ All images in the folder have already been processed!")
            return
        
        print(f"📚 Found {len(unprocessed_files)} new images to process (skipping {len(image_files) - len(unprocessed_files)} already processed)")
        print("🚀 Starting incremental training...")
        
        processed_count = 0
        for image_file in sorted(unprocessed_files):
            try:
                print(f"\n{'='*60}")
                print(f"Image {processed_count + 1}/{len(unprocessed_files)}")
                print(f"{'='*60}")
                
                self.process_image(str(image_file), show_images)
                self.mark_image_processed(image_file)
                processed_count += 1
                
                print(f"\n📊 Progress: {processed_count}/{len(unprocessed_files)} images processed")
                print(f"📋 Known people: {len(self.known_faces)}")
                
                if processed_count < len(unprocessed_files):
                    continue_choice = input("\nPress Enter to continue to next image, or 'q' to quit: ").strip()
                    if continue_choice.lower() == 'q':
                        break
                
            except Exception as e:
                print(f"❌ Error processing {image_file}: {str(e)}")
                continue
        
        print(f"\n🎉 Training completed!")
        print(f"📊 Final stats:")
        print(f"   - Images processed: {processed_count}")
        print(f"   - Known people: {len(self.known_faces)}")
        for name, embeddings in self.known_faces.items():
            print(f"   - {name}: {len(embeddings)} face samples")
    
    def recognize_in_video(self, video_source=0):
        cap = cv2.VideoCapture(video_source)
        
        if not cap.isOpened():
            print("❌ Error: Could not open video source")
            return
        
        print("🎥 Starting video recognition. Press 'q' to quit.")
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            faces, _ = self.detect_faces(frame)
            
            for face_data in faces:
                bbox = face_data['bbox']
                embedding = face_data['embedding']
                
                if len(self.known_faces) > 0:
                    best_match, similarity = self.find_best_match(embedding)
                    
                    if similarity > self.similarity_threshold:
                        label = f"{best_match} ({similarity:.2f})"
                        color = (0, 255, 0)
                    else:
                        label = "Unknown"
                        color = (0, 0, 255)
                else:
                    label = "Unknown"
                    color = (0, 0, 255)
                
                x1, y1, x2, y2 = bbox
                cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                cv2.putText(frame, label, (x1, y1-10), cv2.FONT_HERSHEY_SIMPLEX, 
                        0.6, color, 2)
            
            cv2.imshow('Face Recognition', frame)
            
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
        
        cap.release()
        cv2.destroyAllWindows()
    
    def get_statistics(self):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("SELECT COUNT(*) FROM face_embeddings")
        total_embeddings = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(DISTINCT person_name) FROM face_embeddings")
        unique_people = cursor.fetchone()[0]
        
        cursor.execute("SELECT person_name, COUNT(*) FROM face_embeddings GROUP BY person_name")
        person_counts = cursor.fetchall()
        
        cursor.execute("SELECT COUNT(*) FROM processed_images")
        processed_images_count = cursor.fetchone()[0]
        
        conn.close()
        
        print(f"\n📊 System Statistics:")
        print(f"   - Total face embeddings: {total_embeddings}")
        print(f"   - Unique people: {unique_people}")
        print(f"   - Processed images: {processed_images_count}")
        print(f"   - Face samples per person:")
        for name, count in person_counts:
            print(f"     • {name}: {count} samples")


def main():
    print("🚀 Initializing Face Recognition System...")
    
    recognizer = IncrementalFaceRecognition(
        dataset_path="dataset_arcface",
        similarity_threshold=0.6,
        confidence_threshold=0.8
    )
    
    while True:
        print("\n" + "="*50)
        print("Face Recognition System Menu")
        print("="*50)
        print("1. Train on dataset folder")
        print("2. Process single image")
        print("3. Start video recognition")
        print("4. View statistics")
        print("5. Exit")
        print("-"*50)
        
        choice = input("Enter your choice (1-5): ").strip()
        
        if choice == '1':
            folder_path = input("Enter dataset folder path: ").strip()
            if folder_path:
                recognizer.train_on_dataset(folder_path, show_images=True)
        
        elif choice == '2':
            image_path = input("Enter image path: ").strip()
            if image_path and os.path.exists(image_path):
                recognizer.process_image(image_path, show_images=True)
            else:
                print("❌ Image file not found")
        
        elif choice == '3':
            video_source = input("Enter video source (0 for webcam, or video file path): ").strip()
            if video_source == '0':
                recognizer.recognize_in_video(0)
            elif os.path.exists(video_source):
                recognizer.recognize_in_video(video_source)
            else:
                recognizer.recognize_in_video(0)
        
        elif choice == '4':
            recognizer.get_statistics()
        
        elif choice == '5':
            print("👋 Goodbye!")
            break
        
        else:
            print("❌ Invalid choice. Please try again.")

if __name__ == "__main__":
    main()