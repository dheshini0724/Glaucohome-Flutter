#!/usr/bin/env python3
# train_model.py
# Handles exact structure:
#   dataset/ACRIMA/              <- images directly (filename has label)
#   dataset/Fundus_Train_Val_Data/Fundus_Scanes_Sorted/Glaucoma|Normal/
#   dataset/ORIGA/ORIGA/Images/  <- labels from glaucoma.csv
#   dataset/glaucoma.csv         <- master label file
# Run: python train_model.py

import os, shutil, csv, numpy as np, matplotlib.pyplot as plt
from sklearn.metrics import classification_report, confusion_matrix
import tensorflow as tf
from tensorflow.keras import layers, models
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint

DATASET_DIR  = 'dataset'
PREPARED_DIR = 'dataset_prepared'
IMG_SIZE     = 224
BATCH_SIZE   = 32
EPOCHS       = 30
MODEL_PATH   = 'glaucoma_model.h5'
TFLITE_PATH  = 'glaucoma_model.tflite'
IMG_EXTS     = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.tif'}

def is_image(f):
    return os.path.splitext(f.lower())[1] in IMG_EXTS

def copy_img(src, phase, label, prefix):
    dst_dir = os.path.join(PREPARED_DIR, phase, label)
    os.makedirs(dst_dir, exist_ok=True)
    fname    = f"{prefix}_{os.path.basename(src)}"
    dst_file = os.path.join(dst_dir, fname)
    if not os.path.exists(dst_file):
        shutil.copy2(src, dst_file)

def split_and_copy(paths, label, prefix, val_split=0.15):
    np.random.shuffle(paths)
    split = int(len(paths) * (1 - val_split))
    for p in paths[:split]: copy_img(p, 'train', label, prefix)
    for p in paths[split:]: copy_img(p, 'val',   label, prefix)
    print(f"  {label}: {split} train | {len(paths)-split} val")

# ── Clean prepared dir ────────────────────────────────────────────
if os.path.exists(PREPARED_DIR):
    shutil.rmtree(PREPARED_DIR)

total_glaucoma = 0
total_normal   = 0

# ── SOURCE 1: Fundus_Train_Val_Data ──────────────────────────────
# dataset/Fundus_Train_Val_Data/Fundus_Scanes_Sorted/Glaucoma/
# dataset/Fundus_Train_Val_Data/Fundus_Scanes_Sorted/Normal/
print("="*55)
print("SOURCE 1: Fundus_Train_Val_Data")
sorted_dir = os.path.join(DATASET_DIR, 'Fundus_Train_Val_Data',
                          'Fundus_Scanes_Sorted')

if os.path.exists(sorted_dir):
    for subfolder in os.listdir(sorted_dir):
        sub_path = os.path.join(sorted_dir, subfolder)
        if not os.path.isdir(sub_path): continue
        name_lower = subfolder.lower()
        if 'glaucoma' in name_lower or name_lower == 'g':
            label = 'glaucoma'
        elif 'normal' in name_lower or name_lower == 'n':
            label = 'normal'
        else:
            print(f"  Skipping unknown folder: {subfolder}")
            continue
        imgs = [os.path.join(sub_path, f)
                for f in os.listdir(sub_path) if is_image(f)]
        split_and_copy(imgs, label, 'fundus')
        if label == 'glaucoma': total_glaucoma += len(imgs)
        else: total_normal += len(imgs)
else:
    print("  NOT FOUND — skipping")

# ── SOURCE 2: ACRIMA ─────────────────────────────────────────────
# Images directly in dataset/ACRIMA/
# Filename convention: Im001_g.jpg = glaucoma, Im001_n.jpg = normal
print("\nSOURCE 2: ACRIMA")
acrima_dir = os.path.join(DATASET_DIR, 'ACRIMA')

if os.path.exists(acrima_dir):
    glaucoma_imgs = []
    normal_imgs   = []
    for f in os.listdir(acrima_dir):
        if not is_image(f): continue
        fpath = os.path.join(acrima_dir, f)
        name  = f.lower()
        # ACRIMA naming: _g = glaucoma, _n = normal
        if '_g.' in name or name.startswith('g_') or 'glaucoma' in name:
            glaucoma_imgs.append(fpath)
        elif '_n.' in name or name.startswith('n_') or 'normal' in name:
            normal_imgs.append(fpath)
        else:
            # Default: treat all as glaucoma (ACRIMA is glaucoma dataset)
            glaucoma_imgs.append(fpath)

    if glaucoma_imgs:
        split_and_copy(glaucoma_imgs, 'glaucoma', 'acrima')
        total_glaucoma += len(glaucoma_imgs)
    if normal_imgs:
        split_and_copy(normal_imgs, 'normal', 'acrima')
        total_normal += len(normal_imgs)
    print(f"  Found {len(glaucoma_imgs)} glaucoma, {len(normal_imgs)} normal")
else:
    print("  NOT FOUND — skipping")

# ── SOURCE 3: ORIGA with glaucoma.csv ────────────────────────────
# dataset/ORIGA/ORIGA/Images/  + dataset/glaucoma.csv
print("\nSOURCE 3: ORIGA (via glaucoma.csv)")
origa_img_dir = os.path.join(DATASET_DIR, 'ORIGA', 'ORIGA', 'Images')
csv_path      = os.path.join(DATASET_DIR, 'glaucoma.csv')

if os.path.exists(origa_img_dir) and os.path.exists(csv_path):
    label_map = {}
    with open(csv_path, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        print(f"  CSV columns: {reader.fieldnames}")
        for row in reader:
            # Try common column names
            filename = (row.get('filename') or row.get('image') or
                        row.get('File') or row.get('name') or
                        row.get('ID') or list(row.values())[0])
            label_val = (row.get('label') or row.get('Label') or
                         row.get('glaucoma') or row.get('Glaucoma') or
                         row.get('class') or list(row.values())[-1])
            if filename and label_val:
                lv = str(label_val).strip().lower()
                if lv in ['1', 'yes', 'glaucoma', 'g', 'positive']:
                    label_map[filename.strip()] = 'glaucoma'
                elif lv in ['0', 'no', 'normal', 'n', 'negative']:
                    label_map[filename.strip()] = 'normal'

    g_imgs, n_imgs = [], []
    for f in os.listdir(origa_img_dir):
        if not is_image(f): continue
        fpath = os.path.join(origa_img_dir, f)
        # Match by filename with or without extension
        label = (label_map.get(f) or
                 label_map.get(os.path.splitext(f)[0]) or
                 None)
        if label == 'glaucoma': g_imgs.append(fpath)
        elif label == 'normal': n_imgs.append(fpath)

    if g_imgs:
        split_and_copy(g_imgs, 'glaucoma', 'origa')
        total_glaucoma += len(g_imgs)
    if n_imgs:
        split_and_copy(n_imgs, 'normal', 'origa')
        total_normal += len(n_imgs)
    print(f"  Matched {len(g_imgs)} glaucoma, {len(n_imgs)} normal from CSV")
else:
    print(f"  ORIGA images dir: {'OK' if os.path.exists(origa_img_dir) else 'NOT FOUND'}")
    print(f"  glaucoma.csv    : {'OK' if os.path.exists(csv_path) else 'NOT FOUND'}")

# ── Summary ───────────────────────────────────────────────────────
print("\n" + "="*55)
print(f"TOTAL: {total_glaucoma} glaucoma | {total_normal} normal")
print("="*55)

if total_glaucoma == 0 or total_normal == 0:
    print("ERROR: Missing glaucoma or normal images!")
    exit(1)

# ── Data Generators ───────────────────────────────────────────────
train_gen = ImageDataGenerator(
    rescale=1./255, rotation_range=20,
    width_shift_range=0.1, height_shift_range=0.1,
    horizontal_flip=True, zoom_range=0.15,
    brightness_range=[0.8, 1.2], shear_range=0.1,
).flow_from_directory(
    os.path.join(PREPARED_DIR, 'train'),
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE, class_mode='binary', shuffle=True)

val_gen = ImageDataGenerator(rescale=1./255).flow_from_directory(
    os.path.join(PREPARED_DIR, 'val'),
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE, class_mode='binary', shuffle=False)

print(f"\nClasses : {train_gen.class_indices}")
print(f"Train   : {train_gen.samples}")
print(f"Val     : {val_gen.samples}")

# ── Model ─────────────────────────────────────────────────────────
base = tf.keras.applications.MobileNetV2(
    input_shape=(IMG_SIZE, IMG_SIZE, 3),
    include_top=False, weights='imagenet')
base.trainable = False

model = models.Sequential([
    base,
    layers.GlobalAveragePooling2D(),
    layers.BatchNormalization(),
    layers.Dense(256, activation='relu'),
    layers.Dropout(0.5),
    layers.Dense(64, activation='relu'),
    layers.Dropout(0.3),
    layers.Dense(1, activation='sigmoid'),
])

cbs = [
    EarlyStopping(monitor='val_auc', patience=6,
                  restore_best_weights=True, mode='max'),
    ModelCheckpoint(MODEL_PATH, monitor='val_auc',
                    save_best_only=True, mode='max'),
]

def compile_m(lr):
    model.compile(
        optimizer=tf.keras.optimizers.Adam(lr),
        loss='binary_crossentropy',
        metrics=['accuracy',
                 tf.keras.metrics.Precision(name='precision'),
                 tf.keras.metrics.Recall(name='recall'),
                 tf.keras.metrics.AUC(name='auc')])

print("\nPhase 1: Training top layers...")
compile_m(1e-4)
h1 = model.fit(train_gen, validation_data=val_gen, epochs=15, callbacks=cbs)

print("\nPhase 2: Fine-tuning...")
base.trainable = True
for layer in base.layers[:-30]: layer.trainable = False
compile_m(1e-5)
h2 = model.fit(train_gen, validation_data=val_gen,
               epochs=EPOCHS, initial_epoch=15, callbacks=cbs)

# ── Results ───────────────────────────────────────────────────────
print("\n" + "="*55)
res = model.evaluate(val_gen, verbose=0)
print(f"Accuracy  : {res[1]*100:.2f}%")
print(f"Precision : {res[2]*100:.2f}%")
print(f"Recall    : {res[3]*100:.2f}%")
print(f"AUC       : {res[4]*100:.2f}%")

val_gen.reset()
preds  = (model.predict(val_gen, verbose=0) > 0.5).astype(int).flatten()
labels = val_gen.classes
print(classification_report(labels, preds,
      target_names=['Glaucoma','Normal']))
cm = confusion_matrix(labels, preds)
print(f"TN={cm[0][0]} FP={cm[0][1]} FN={cm[1][0]} TP={cm[1][1]}")
print(f"Sensitivity: {cm[1][1]/(cm[1][1]+cm[1][0]+1e-7)*100:.2f}%")
print(f"Specificity: {cm[0][0]/(cm[0][0]+cm[0][1]+1e-7)*100:.2f}%")

# ── TFLite export ─────────────────────────────────────────────────
print("\nConverting to TFLite...")
conv = tf.lite.TFLiteConverter.from_keras_model(model)
conv.optimizations = [tf.lite.Optimize.DEFAULT]
with open(TFLITE_PATH, 'wb') as f: f.write(conv.convert())
print(f"Saved: {TFLITE_PATH} ({os.path.getsize(TFLITE_PATH)/1024:.0f} KB)")
print("\nDone! Now run: python app.py")
