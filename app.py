#!/usr/bin/env python3
from flask import Flask, request, jsonify
import cv2, numpy as np, base64, math, os, json
import tensorflow as tf

# ── Numpy JSON fix ────────────────────────────────────────────────
class NumpyEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, np.integer): return int(obj)
        if isinstance(obj, np.floating): return float(obj)
        if isinstance(obj, np.ndarray): return obj.tolist()
        return super().default(obj)

app = Flask(__name__)
app.json_encoder = NumpyEncoder

# ── Load ML model ─────────────────────────────────────────────────
MODEL_PATH   = 'glaucoma_model.tflite'
IMG_SIZE     = 224
ml_available = False
interpreter  = None

if os.path.exists(MODEL_PATH):
    try:
        interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
        interpreter.allocate_tensors()
        ml_available = True
        print("✅ ML model loaded successfully")
    except Exception as e:
        print(f"⚠️  ML model load failed: {e}")
else:
    print("⚠️  No TFLite model found.")

NORMAL_MIN     = 2.5
NORMAL_MAX     = 4.5
BORDERLINE_MIN = 2.0
AVG_CORNEAL_MM = 11.7

def classify_risk(acd_mm):
    if NORMAL_MIN <= acd_mm <= NORMAL_MAX:
        return "Normal", "ACD is within normal range (2.5-4.5 mm). Low risk."
    elif BORDERLINE_MIN <= acd_mm < NORMAL_MIN:
        return "Borderline", "ACD slightly shallow. Consult an ophthalmologist."
    elif acd_mm > NORMAL_MAX:
        return "Deep Chamber", "ACD unusually deep. Seek evaluation."
    else:
        return "High Risk", "ACD critically shallow. HIGH glaucoma risk!"

def predict_with_ml(img_bgr):
    if not ml_available:
        return None
    try:
        img_rgb     = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        img_resized = cv2.resize(img_rgb, (IMG_SIZE, IMG_SIZE))
        img_norm    = img_resized.astype(np.float32) / 255.0
        img_batch   = np.expand_dims(img_norm, axis=0)
        inp = interpreter.get_input_details()
        out = interpreter.get_output_details()
        interpreter.set_tensor(inp[0]['index'], img_batch)
        interpreter.invoke()
        prob  = float(interpreter.get_tensor(out[0]['index'])[0][0])
        label = "Glaucoma Detected" if prob > 0.5 else "No Glaucoma"
        return prob, label
    except Exception as e:
        print(f"ML error: {e}")
        return None

def detect_acd_opencv(img):
    try:
        h, w  = img.shape[:2]
        gray  = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        clahe = cv2.createCLAHE(clipLimit=4.0, tileGridSize=(8,8))
        enhanced = clahe.apply(gray)
        _, mask  = cv2.threshold(enhanced, 240, 255, cv2.THRESH_BINARY)
        kernel   = np.ones((5,5), np.uint8)
        mask     = cv2.dilate(mask, kernel, iterations=1)
        enhanced = cv2.inpaint(enhanced, mask, 5, cv2.INPAINT_TELEA)
        blurred  = cv2.GaussianBlur(enhanced, (11,11), 2)
        min_dim  = min(w, h)

        pupil_circles = None
        for p2 in [20, 15, 12, 10, 8]:
            pupil_circles = cv2.HoughCircles(
                blurred, cv2.HOUGH_GRADIENT, dp=1.2, minDist=30,
                param1=50, param2=p2,
                minRadius=int(min_dim*0.03), maxRadius=int(min_dim*0.22))
            if pupil_circles is not None: break

        iris_circles = None
        for p2 in [25, 20, 15, 12, 10]:
            iris_circles = cv2.HoughCircles(
                blurred, cv2.HOUGH_GRADIENT, dp=1.2, minDist=50,
                param1=50, param2=p2,
                minRadius=int(min_dim*0.12), maxRadius=int(min_dim*0.55))
            if iris_circles is not None: break

        if pupil_circles is None or iris_circles is None:
            return None, None, None, "Pupil/iris not detected."

        pupils = np.round(pupil_circles[0]).astype(int)
        irises = np.round(iris_circles[0]).astype(int)
        cx, cy = w//2, h//2
        best_pupil, best_iris, best_score = None, None, float('inf')

        for p in pupils:
            px, py, pr = int(p[0]), int(p[1]), int(p[2])
            for i in irises:
                ix, iy, ir = int(i[0]), int(i[1]), int(i[2])
                if pr >= ir: continue
                dist = math.sqrt((px-ix)**2 + (py-iy)**2)
                if dist > ir*0.5: continue
                score = math.sqrt((ix-cx)**2 + (iy-cy)**2)
                if score < best_score:
                    best_score = score
                    best_pupil = [px, py, pr]
                    best_iris  = [ix, iy, ir]

        if best_pupil is None:
            best_iris = [int(x) for x in max(irises, key=lambda c: c[2])]
            ix, iy, ir = best_iris
            candidates = [[int(p[0]),int(p[1]),int(p[2])] for p in pupils
                          if int(p[2]) < ir and
                          math.sqrt((int(p[0])-ix)**2+(int(p[1])-iy)**2) < ir*0.7]
            if not candidates:
                return None, None, None, "Eye not centered. Fill oval guide."
            best_pupil = min(candidates, key=lambda c: c[2])

        pr, ir_r = best_pupil[2], best_iris[2]
        acd_px   = (ir_r - pr) * 0.6
        acd_mm   = round(float(acd_px * (AVG_CORNEAL_MM / (ir_r * 2))), 2)
        return acd_mm, best_pupil, best_iris, None

    except Exception as e:
        print(f"OpenCV error: {e}")
        import traceback; traceback.print_exc()
        return None, None, None, f"OpenCV error: {str(e)}"

def detect_acd(image_bytes):
    try:
        nparr = np.frombuffer(image_bytes, np.uint8)
        img   = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None: return None, "Could not decode image"

        h, w = img.shape[:2]
        if w > 1000: img = cv2.resize(img, (1000, int(h*1000/w)))

        ml_result     = predict_with_ml(img)
        ml_prob       = None
        ml_label      = None
        ml_confidence = None

        if ml_result:
            ml_prob, ml_label = ml_result
            ml_confidence = round(
                ml_prob*100 if ml_prob > 0.5 else (1-ml_prob)*100, 1)

        acd_mm, best_pupil, best_iris, cv_error = detect_acd_opencv(img)

        if acd_mm is None and ml_result is None:
            return None, cv_error or "Detection failed."

        if ml_result:
            if ml_prob > 0.5:
                risk_level = "Glaucoma Risk Detected"
                risk_desc  = (f"ML detected glaucoma with {ml_confidence}% confidence. "
                              + (f"ACD: {acd_mm} mm. " if acd_mm else "")
                              + "Consult an ophthalmologist.")
            else:
                risk_level = "Low Risk"
                risk_desc  = (f"No glaucoma signs ({ml_confidence}% confidence). "
                              + (f"ACD: {acd_mm} mm. " if acd_mm else "")
                              + "Continue regular check-ups.")
        else:
            risk_level, risk_desc = classify_risk(acd_mm)

        debug_img = img.copy()
        if best_pupil and best_iris:
            px, py, pr = best_pupil
            ix, iy, ir = best_iris
            cv2.circle(debug_img, (ix,iy), ir, (0,255,0), 2)
            cv2.circle(debug_img, (px,py), pr, (0,0,255), 2)
            cv2.circle(debug_img, (px,py),  3, (255,0,0), -1)

        color = (0,0,255) if "Risk" in risk_level or "Glaucoma" in risk_level else (0,255,0)
        cv2.putText(debug_img, risk_level, (20,40), cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2)
        if acd_mm:
            cv2.putText(debug_img, f"ACD: {acd_mm}mm", (20,75),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0,255,255), 2)
        if ml_confidence:
            cv2.putText(debug_img, f"ML: {ml_confidence}%", (20,108),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255,255,0), 2)

        _, buf    = cv2.imencode('.jpg', debug_img)
        debug_b64 = base64.b64encode(buf).decode('utf-8')

        return {
            "acd_pixels":          float(round((best_iris[2]-best_pupil[2])*0.6,1)) if best_pupil else 0.0,
            "acd_mm":              float(acd_mm) if acd_mm else 0.0,
            "risk_level":          str(risk_level),
            "risk_description":    str(risk_desc),
            "corneal_diameter_px": float(best_iris[2]*2) if best_iris else 0.0,
            "pupil_radius_px":     int(best_pupil[2]) if best_pupil else 0,
            "iris_radius_px":      int(best_iris[2])  if best_iris  else 0,
            "ml_label":            str(ml_label or "Not available"),
            "ml_confidence":       float(ml_confidence or 0),
            "ml_available":        bool(ml_available),
            "debug_image_base64":  debug_b64,
            "detection_success":   True,
        }, None

    except Exception as e:
        import traceback; traceback.print_exc()
        return None, f"Server error: {str(e)}"

@app.route('/analyze', methods=['POST'])
def analyze():
    try:
        if 'image' not in request.files:
            return jsonify({"detection_success":False,"risk_level":"Unknown",
                "risk_description":"No image received.",
                "acd_mm":0,"acd_pixels":0,"corneal_diameter_px":0}), 200
        result, error = detect_acd(request.files['image'].read())
        if error:
            return jsonify({"detection_success":False,"risk_level":"Unknown",
                "risk_description":error,
                "acd_mm":0,"acd_pixels":0,"corneal_diameter_px":0}), 200
        return jsonify(result), 200
    except Exception as e:
        import traceback; traceback.print_exc()
        return jsonify({"detection_success":False,"risk_level":"Unknown",
            "risk_description":f"Server error: {str(e)}",
            "acd_mm":0,"acd_pixels":0,"corneal_diameter_px":0}), 200

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status":"ok","ml_available":ml_available}), 200

if __name__ == '__main__':
    print("="*50)
    print("GlaucoScan OpenCV + ML API starting...")
    print(f"ML Model: {'✅ Loaded' if ml_available else '⚠️  Not found'}")
    print("Make sure phone and PC are on SAME WiFi")
    print("="*50)
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
