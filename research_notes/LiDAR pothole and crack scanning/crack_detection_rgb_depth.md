# Crack detection and width/length measurement on iPhone (RGB + LiDAR, on-device ML)

Scope: an on-device iOS 18+ Swift pipeline. Segment cracks in the high-resolution RGB image, then convert pixel measurements to millimetres using LiDAR depth plus ARCamera intrinsics, or a fitted ground plane.

## 1. Crack segmentation models and datasets: performance, size, licence, CoreML conversion, Neural Engine speed

### Takeaway
The quickest route is a YOLOv8/YOLO11/YOLO26-seg model trained on the public-domain Ultralytics/Roboflow Crack-seg dataset (4,029 images) and exported with `format=coreml`. Ultralytics benchmarks YOLO26n-seg at about 4.8 ms per image on an iPhone 17 Pro with the Neural Engine. Ultralytics code and weights are AGPL-3.0, so a closed-source commercial app needs an Ultralytics Enterprise licence or a permissively licensed alternative. Apache-2.0 HrSegNet trained on CrackSeg9k is one option; a small U-Net or SegFormer-B0 converted with coremltools is another. For fine-width work, a semantic (per-pixel) model is better than instance masks, because YOLO-seg masks are produced at reduced resolution (inference, see below).

### Cited Findings
**Datasets**
- CrackSeg9k (ECCV 2022 workshop, Kulkarni et al.) merges smaller open-source crack datasets into 9,255 images with harmonised labels, split 90/5/5 train/val/test. — [arXiv 2208.13054](https://arxiv.org/pdf/2208.13054); code: github.com/Dhananjay42/crackseg9k (per the same search results)
- CrackSeg9k benchmark mIoU per sub-dataset (Table 1 snippet): DeepCrack sub-dataset about 0.72 with Pix2Pix U-Net and about 0.83 with DeepLab ResNet; Masonry sub-dataset about 0.47 and 0.50. I only saw these in a snippet, so they should be checked against the full table. — [ar5iv CrackSeg9k](https://ar5iv.labs.arxiv.org/html/2208.13054)
- CrackUDA, which uses CrackSeg9k as its source domain, reports mIoU of about 0.78–0.83 in its source-domain step. — [arXiv 2412.15637](https://arxiv.org/pdf/2412.15637)
- khanhha/crack_segmentation ("Khanh11k"): about 11,200 images merged from about 12 datasets (CRACK500, GAPs384, CFD, AEL, CrackTree200, DeepCrack and others, plus about 300 self-labelled high-res images), resized to 448×448. Reported results: UNet_VGG16 IoU 0.4687 / Dice 0.6033; UNet_ResNet101 IoU 0.3861 / Dice 0.519. The README text contradicts its own table about which model is best. The repo states no licence and asks users to cite the original datasets. — [GitHub khanhha/crack_segmentation](https://github.com/khanhha/crack_segmentation)
- DeepCrack dataset (yhlleo): use is "RESTRICTED to non-commercial research and educational purposes". The README gives no standard code licence. — [GitHub yhlleo/DeepCrack](https://github.com/yhlleo/DeepCrack)
- Ultralytics Crack-seg dataset: 4,029 images (3,717 train / 200 val / 112 test), one class `crack` covering roads and walls. It comes from Roboflow Universe project university-bswxt/crack-bphdr (Dec 2022) and is marked Public Domain (CC PDM 1.0), although the YAML config header says AGPL-3.0. No benchmark metrics are published. — [Ultralytics Crack-seg docs](https://docs.ultralytics.com/datasets/segment/crack-seg/)
- An iPad Pro LiDAR pavement study notes that LiDAR-only scans could not detect small cracks (best resolution about 1 cm). This supports doing detection in RGB. — [ROSAP / MTI pavement LiDAR study](https://rosap.ntl.bts.gov/view/dot/75721)

**Models and metrics (all self-reported, splits differ between papers, so the numbers are not directly comparable)**
- CFD (CrackForest): CrackCLF reports ODS 0.9374 / OIS 0.9455 / F1 0.9406; U-HDN reports ODS 0.935. — [CrackCLF arXiv 2311.11815](https://arxiv.org/pdf/2311.11815)
- DeepCrack: a staircase cascaded-fusion network reports ODS 0.8914 / F1 0.9079; the CT-crackseg baseline gets ODS 0.8819 / F1 0.8952. — [arXiv 2408.12815](https://arxiv.org/pdf/2408.12815)
- Crack500: one paper reports F1 74.19% against 71.44% for a U-Net baseline. Crack500 scores are generally much lower than CFD/DeepCrack scores. — [search result set, arXiv 2305.05132 / 2501.18855](https://arxiv.org/pdf/2501.18855)
- Generalisation across datasets drops sharply. In FlexiCrackNet's zero-shot test (train on DeepCrack, test on CFD), baselines such as SegNet fall to roughly 30–44% on some metrics. — [FlexiCrackNet arXiv 2501.18855](https://arxiv.org/pdf/2501.18855)
- SegFormer on the CrackVision12k leaderboard: mIoU 0.580 (variant unspecified). — [PapersWithCode crack segmentation](https://PapersWithCode.com/task/crack-segmentation)
- EfficientCrackNet (lightweight CNN + transformer): 0.26 M parameters, 0.483 GFLOPs, evaluated on Crack500, DeepCrack and GAPs384. Metric values are not in the abstract. — [arXiv 2409.18099](https://arxiv.org/abs/2409.18099v1)
- HrSegNet (B16/B32/B48/B64) with trained CrackSeg9k weights: licence Apache-2.0; TensorRT engines at 400×400 input. Numeric metrics appear only in a figure on the README. — [GitHub HrSegNet4CrackSegmentation](https://github.com/CHDyshli/HrSegNet4CrackSegmentation)
- OpenSistemas/YOLOv8-crack-seg (HF): YOLOv8 n/s/m/l/x-seg trained on Crack-seg (4,029 images), licence AGPL-3.0. Metrics are on W&B only and were not reported on the card. — [HF OpenSistemas/YOLOv8-crack-seg](https://huggingface.co/OpenSistemas/YOLOv8-crack-seg/blob/main/README.md)
- beaunix/smart-crack-vision: YOLOv8n-seg trained on the Ultralytics Crack-seg dataset; licence not confirmed. — [HF beaunix/smart-crack-vision](https://huggingface.co/beaunix/smart-crack-vision)
- Ultralytics code is AGPL-3.0. — [HF mirror of ultralytics file header](https://huggingface.co/spaces/imesper/FastSAM/blob/main/ultralytics/yolo/v8/__init__.py)

**CoreML export and iPhone speed**
- Ultralytics CoreML export supports detect, segment, semantic, depth, classify, pose and OBB. Segment works for YOLOv8, YOLO11 and YOLO26; semantic segmentation is YOLO26 only. Arguments: `imgsz` (default 640, accepts a (h,w) tuple), `quantize` (16 / 8 / "w8a16"; replaces the deprecated `half`/`int8`), `nms` (embed NMS for detect/segment/pose, requires `dynamic=False`), `dynamic`. — [Ultralytics CoreML integration](https://docs.ultralytics.com/integrations/coreml/)
- Measured on an iPhone 17 Pro (A19 Pro, 16-core ANE, iOS 26.5.2) with YOLO26n INT8, single-image latency: Segment 640 is 12.6 ms CPU-only and 4.8 ms CPU+ANE; Detect 640 is 9.2 ms and 3.2 ms. Sustained real-time camera use is slower. — [Ultralytics CoreML integration](https://docs.ultralytics.com/integrations/coreml/); the localized doc gives YOLO26n detection 3.8 ms single-image and 11.3 ms/frame in continuous camera use — [Ultralytics CoreML (tr)](https://docs.ultralytics.com/tr/integrations/coreml)
- YOLO11n-seg 3.0 ms vs YOLO11x-seg 24.8 ms on non-iPhone hardware (orchard paper). — [arXiv 2412.05728](https://arxiv.org/pdf/2412.05728)
- Roboflow reports an anecdotal CoreML/ANE speed-up of 21 to 85 FPS (device and variant unspecified). — [Roboflow blog](https://roboflow.com/blog/best-ios-object-detection-models)

### Inferences
- Recommended model choice: (a) prototype with YOLO11n-seg or YOLO26n-seg fine-tuned on Crack-seg plus your own floor/pavement images, exported with `format=coreml, quantize=16`; (b) for a commercial closed-source app, either buy an Ultralytics licence or train a permissive U-Net / SegFormer-B0 / HrSegNet (Apache-2.0) on CrackSeg9k and convert it via PyTorch → `torch.jit.trace` → `coremltools.convert(..., compute_units=.ALL)`.
- Dataset licences matter separately from model licences. DeepCrack is non-commercial, CrackSeg9k and Khanh11k are merges that inherit their sub-dataset licences (some unclear or non-commercial), and Crack-seg is public domain.
- YOLO-seg masks are prototype-based and typically produced at 1/4 of the input resolution (160×160 for a 640 input). That is too coarse for sub-mm width. Use YOLO for detection/ROI, then run a full-resolution semantic model or classical refinement on high-res crops (tile the 4032×3024 image into 512–640 px tiles). This is my architectural inference, not taken from a source.
- At ≤5 ms per 640 tile on recent ANEs, tiling a 12 MP still (about 35 tiles at 640 with no overlap) should take a few hundred ms on recent devices and more on A14. That is fine for single-shot measurement, not for live video. This is an extrapolation and should be benchmarked on A14.

### Gaps
- No published iPhone ANE latency for crack-specific U-Net/SegFormer models, and no A14-specific numbers for YOLO-seg; this needs an on-device benchmark (Xcode Core ML performance report).
- mAP for the OpenSistemas YOLOv8-crack-seg variants was not retrievable (W&B images only).
- Full CrackSeg9k Table 1 values and the HrSegNet metrics (figure only) were not verified.
- No public model trained specifically on indoor floor cracks (tile, screed, epoxy) was found.

## 2. Measuring crack width and length from a mask; accuracy vs. ground sampling distance; minimum measurable width

### Takeaway
The standard method is to skeletonise the mask, take 2× the Euclidean distance transform at the skeleton pixels as the width, and take the summed skeleton arc length as the length. Orthogonal-projection (edge-to-edge perpendicular to the local skeleton direction) or sub-pixel edge methods reduce over-estimation at branches and oblique cracks. Image-based accuracy depends mainly on how many pixels span the crack. At iPhone resolutions and 0.3–0.5 m, the GSD is about 0.1–0.33 mm/px, so reliable widths start at roughly 0.3–1 mm; hairline cracks under 0.2 mm can be detected but not measured accurately.

### Cited Findings
- Standard workflow: threshold or segment, compute the Euclidean distance transform, skeletonise, multiply the two, and double the radius to get width. Width varies along the crack, so report max/mean/percentiles. — [MATLAB Central answer](https://www.mathworks.com/matlabcentral/answers/223717-crack-width-measurement-on-binary-images); [MATLAB Central: How to measure crack width](https://au.mathworks.com/matlabcentral/answers/1924750-how-to-measure-crack-width)
- A study (MDPI Eng 6(6):122) thins the crack to a centreline skeleton and uses a Euclidean distance transform for maximum and average width. In a Taiwanese thesis/app validated against a calibration plate, width deviations were mostly −0.5 mm to +0.6 mm, and the distance-to-surface measurement added error (−5 mm to +3 mm for one method). — [MDPI Eng 6(6):122](https://www.mdpi.com/2673-4117/6/6/122); [Airiti thesis U0020-2108202221494100](https://www.airitilibrary.com/Article/Detail/U0020-2108202221494100)
- MDPI Buildings 2025: skeleton pruning plus an "edge-OrthoBoundary" algorithm. The authors note that existing image methods over-estimate width on complex geometries or are computationally inefficient. — [MDPI Buildings 15(14):2489](https://www.mdpi.com/2075-5309/15/14/2489)
- Pavement crack width via cascaded PCA: orthogonal projection measures width from boundary contours, and rectangle-based methods tend to under-estimate on alligator cracks. — [arXiv 2511.02144](https://arxiv.org/pdf/2511.02144)
- A laser-spot scale method (spot diameter vs. camera distance gives mm/px) had a maximum absolute width error of 0.57 mm and a minimum of 0.02 mm. — [Applied Sciences 2023 (DOAJ)](https://doaj.org/article/30b8e36351044dbdbf2aac434e9b6ad8)
- Older crack measurement system: a target of 0.1 mm RMS for 0.1–3.0 mm cracks required image resolution finer than 0.025 mm/px. — [ISPRS XXIX part5 paper 155](https://WWW.ISPRS.org/proceedings/XXIX/congress/part5/155_XXIX-part5.pdf)
- The number of pixels across the working distance strongly affects width accuracy. Cracks ≤0.1 mm were measurable within 1 m with 100/135 mm lenses but hardly at all with 50 mm. — [Applied Sciences 2021 (DOAJ)](https://doaj.org/article/b6c6bb5b5a1841d0887ff3a96f2f516f)
- Patent: cracks narrower than 5 px need a special single-pixel-skeleton plus Zernike-moment sub-pixel method. — [US 11551341](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/11551341)
- Partial-area sub-pixel edge method (Buildings 2024): maximum relative width errors of 3.06% (horizontal), 8.97% (vertical), 5.16% (oblique); crack length error <0.30 mm. — [Buildings Jan 2024 (DOAJ)](https://doaj.org/article/0e893c5646d74c7da7e60e62133afeb3)
- Fused camera + LiDAR system (DeepLabv3+ refined by SAM, multi-frame VI-LiDAR fusion, measurement in the 3D point cloud) reports mean absolute width error <0.1 mm and mean relative error <15%, with the largest relative errors on the narrowest cracks. — [arXiv 2501.09203](https://arxiv.org/pdf/2501.09203) (figures from the search summary; full text not parsed)

### Inferences (GSD worked example; my calculations, not from a source)
- Pinhole model: GSD (mm/px) ≈ Z / f_px, for a fronto-parallel view.
- The iPhone wide camera is about 26 mm 35mm-equivalent. For a 4032×3024 still (5040 px diagonal vs. 43.27 mm full-frame diagonal), f ≈ 26·5040/43.27 ≈ 3,030 px; scaled to 1920×1440 it is ≈ 1,440 px. Read the real values from `ARCamera.intrinsics` (fx, fy); developer reports of about 1,450–1,600 px at 1920×1440 are plausible but unverified here.
- | Resolution | Z = 0.3 m | Z = 0.5 m |
  |---|---|---|
  | 1920×1440 (f≈1440–1600 px) | ≈0.19–0.21 mm/px | ≈0.31–0.35 mm/px |
  | 3840×2160 4K video (crop; f≈2,880 px, assumed) | ≈0.10 mm/px | ≈0.17 mm/px |
  | 4032×3024 still (f≈3,030 px) | ≈0.10 mm/px | ≈0.165 mm/px |
- A crack can be detected even below 1 px wide (it shows as a dark contrast line), but width from a binary mask is quantised to about ±1 px. Requiring ≥3 px across the crack for ±30% accuracy (consistent with the patent's <5 px threshold for needing sub-pixel methods) gives a minimum reliably measurable width of about 0.3 mm (4032 still at 0.3 m), about 0.5 mm (4032 at 0.5 m or 1920 at 0.3 m), and about 1 mm (1920 at 0.5 m). Sub-pixel edge methods on grey-level profiles across the skeleton normal could push this to about 1–2 px.
- Oblique viewing increases GSD by a factor of 1/cos(θ) along the tilt direction. Measure width perpendicular to the crack in the metric plane, not in image pixels, by projecting the edge points to 3D or to the plane (see Q3).
- Practical floor guidance: hold the phone at about 0.25–0.35 m, roughly fronto-parallel, and use the 12 MP still. ARKit uses the wide camera, so the ultra-wide macro mode is not available in ARKit sessions (inference; not verified).

### Gaps
- No source found that gives a standard error-vs-GSD curve specifically for smartphone captures.
- The MDPI Eng 6(6):122 full text returned 403, so the device and setup details in that paper were not verified.
- Error figures from arXiv 2501.09203 could not be extracted from the full PDF (compressed streams); they come from the search summary only.

## 3. Getting metric scale on iPhone: intrinsics + LiDAR depth, ground-plane ray intersection, multi-frame stitching, capturedImage vs. captureHighResolutionFrame

### Takeaway
Use ARKit world tracking with `.sceneDepth` (or `.smoothedSceneDepth`) and take metric scale from a RANSAC plane fitted to the confidence-filtered LiDAR points. Per-pixel LiDAR depth is too coarse at 256×192 to measure crack geometry directly. Intersect each high-res mask pixel's camera ray (from scaled intrinsics and the camera pose) with that plane to get 3D points in mm, then measure width and length on the plane. Since iOS 16, `captureHighResolutionFrame` returns an `ARFrame` with the full-sensor 12 MP image "and all other frame properties", without interrupting the session. The camera pose and world-anchored plane therefore stay valid across shots, which allows multi-frame stitching in world coordinates.

### Cited Findings
- WWDC22 "Discover ARKit 6": `captureHighResolutionFrame` delivers "an ARFrame containing the high-resolution image and all other frame properties asynchronously". On iPhone 13 that is the full 12 MP of the wide camera, captured "out-of-band" while the video stream keeps running. It requires setting `config.videoFormat = ARWorldTrackingConfiguration.recommendedVideoFormatForHighResolutionFrameCapturing`. The session does not say explicitly whether depth is attached. — [WWDC22 10126](https://developer.apple.com/videos/play/wwdc2022/10126/)
- ARKit 6 adds a 4K video format (`recommendedVideoFormatFor4KResolution`): 3840×2160 at 30 fps, 16:9, no binning, on iPhone 11+ and M1 iPad Pro. — [WWDC22 10126](https://developer.apple.com/videos/play/wwdc2022/10126/); [Road to VR](https://roadtovr.com/?p=171107)
- Object Capture (WWDC22 10128) uses the same captureHighResolutionFrame API and `configurableCaptureDevice ForPrimaryCamera` for focus/exposure/white-balance control. — [WWDC22 10128](https://developer.apple.com/videos/play/wwdc2022-10128)
- `sceneDepth` is updated every frame with LiDAR data. The `confidenceMap` (UInt8, low/medium/high) lets you filter lower-accuracy depth, and confidence is lower on highly reflective or light-absorbing surfaces. — [Apple ARDepthData docs](https://developer.apple.com/documentation/arkit/ardepthdata.md); [confidenceMap docs](https://developer.apple.com/documentation/arkit/ardepthdata/confidencemap.md)
- The depth map is 256×192 paired with 1920×1440 RGB at 30 fps. A third-party forum claim says it is ML-interpolated from about 576 raw laser points. — [arXiv 2310.14437](https://arxiv.org/pdf/2310.14437); [Apple Dev Forums / CurvSurf replies](https://origin-devforums.apple.com/forums/profile/CurvSurf/replies?page=2)
- ARKitScenes evaluation: ARKit's confidence map flags an average of about 1.63% of points as low confidence, while ground-truth laser data has about 12.55% missing. — [arXiv 2310.14437](https://arxiv.org/pdf/2310.14437)
- Apple forum guidance: the accuracy of individual depth values depends heavily on confidence; test live. — [Apple Dev Forums thread 650628](https://developer.apple.com/forums/thread/650628)
- Smartphone LiDAR absolute error across measured directions was <1.1 mm (relative ≤2.12%) in a 2025 multi-phone study (not crack-specific). — [Sensors & Materials SM4222](https://sensors.myu-group.co.jp/sm_pdf/SM4222.pdf)
- Mobile-LiDAR point-cloud crack width on an RC beam: scans supported by SMT (reference targets) reached about ±0.50 mm mean deviation, unreferenced scans exceeded 1.5 mm, and high-density outputs (PIX4Dcatch, Sitescape) over-estimated width. — [Erciyes avesis record](https://avesis.erciyes.edu.tr/publication/details/f02a9c53-16cf-4f97-8c6c-fcaa8f8e6632/oai)
- iPad Pro LiDAR pavement mapping: best resolution about 1 cm, unable to detect smaller cracks or shallow potholes. — [ROSAP dot/75721](https://rosap.ntl.bts.gov/view/dot/75721)

### Inferences (pipeline design; my synthesis)
1. Configure `ARWorldTrackingConfiguration` with `frameSemantics = [.sceneDepth, .smoothedSceneDepth]`, `videoFormat = recommendedVideoFormatForHighResolutionFrameCapturing`, and optionally `planeDetection = .horizontal`.
2. Plane: from the latest frame(s), unproject depth pixels with confidence == .high using the intrinsics scaled to 256×192 (fx·256/W_img, etc.) and `camera.transform`, then run RANSAC for a plane, giving a world-space normal n and offset d. Accumulating several frames reduces noise. ARKit's `ARPlaneAnchor` or a raycast to `.estimatedPlane` / `existingPlaneGeometry` can serve as a fallback or cross-check.
3. Capture: call `session.captureHighResolutionFrame`. Use `frame.camera.intrinsics` and `frame.camera.transform` from the returned ARFrame. If the intrinsics turn out to refer to a different resolution, scale them by the ratio of `capturedImage` dimensions to `camera.imageResolution` (verify on device).
4. Segment on tiles, then for each skeleton point and its two orthogonal edge points, build a ray through the pixel, r = K⁻¹[u,v,1], and rotate it to world space. Intersect it with the plane to get 3D points; width is the distance between the edge points in mm, and length is the sum of 3D distances along the skeleton. This removes perspective and tilt errors that a single mm/px factor would introduce.
5. Multi-frame stitching: because every high-res ARFrame shares the world frame, project masks onto a common plane-aligned ortho-mosaic (for example at 0.1 mm/cell) and fuse by max/vote. Watch for VIO drift of a few mm over larger areas; use `ARWorldMap` relocalisation or image-feature registration for long cracks.
6. Plane-ray intersection scale error ≈ relative depth error. LiDAR has roughly mm-level error at 0.3 m; averaging over thousands of plane points makes the mm/px scale error well under 1%. Width error is therefore dominated by pixel quantisation and segmentation boundaries, not by depth.
- Expected accuracy: roughly ±0.1–0.2 mm (about ±1 px at the 12 MP still at 0.3 m) on cracks ≥0.5 mm. This is consistent with the −0.5/+0.6 mm smartphone app result and the <0.1 mm mean error of fused rigs, but it is unvalidated and needs a calibration-plate test.

### Gaps
- Apple's reference page for `captureHighResolutionFrame` could not be fetched (JS page). Whether the returned ARFrame's `sceneDepth` is populated, and whether its `camera.intrinsics` is already scaled to the 12 MP image, must be verified on device. WWDC only says "all other frame properties".
- No formal RMSE-vs-distance benchmark for the 256×192 depth map was found.
- The minimum LiDAR working distance and depth quality at 0.2–0.3 m on dark asphalt were not sourced.

## 4. Classic non-ML alternatives and when they suffice

### Takeaway
Adaptive/local thresholding, morphology (black-hat/top-hat plus area filtering) and Hessian vesselness (Frangi) filters work for clean, uniform surfaces such as polished concrete, screed or tile with dark, high-contrast cracks. They are noisy on textured asphalt, with shadows, stains and joints, where CNNs clearly win. Their best role is as a sub-pixel refinement or post-processing step inside the ML ROI, or as a fallback that needs no model download.

### Cited Findings
- Early road-crack methods exploited the fact that cracks are darker than the background, but choosing a threshold is hard. — [arXiv 2002.03241 (ensemble CNN)](https://arxiv.org/pdf/2002.03241)
- On the AigleRN benchmark, Canny and local thresholding fail to give continuous cracks and are noise-sensitive. An ensemble CNN reached F1 0.9238 vs. about 0.667 for local thresholding; local threshold had high recall (0.9345) but low precision. — [arXiv 2002.03241](https://arxiv.org/pdf/2002.03241)
- In 3D concrete images, Frangi, Sheet and Hessian-percolation filters were the best classical methods when properly tuned. — [arXiv 2112.09493](https://arxiv.org/pdf/2112.09493)
- CNN plus autotuned thresholding: about 1.4% gain in AFβ on GAPs. — [arXiv 2104.10511](https://arxiv.org/pdf/2104.10511)
- A review claims the "Franji [Frangi] filter" reaches about 98.7% accuracy without giving protocol details (weak evidence). — [DOAJ review 2024](https://doaj.org/article/058b861068a444fd95b715e62e833ed4)
- CrackSeg9k proposes combining image processing with DL models. — [arXiv 2208.13054](https://arxiv.org/pdf/2208.13054)

### Inferences
- On iOS, classical steps map well to Core Image, vImage and Metal Performance Shaders (Gaussian derivatives for the Hessian, morphology, `MPSImageEuclideanDistanceTransform`, thresholding) and run in milliseconds on 12 MP. Skeletonisation (Zhang-Suen) is simple to write in a Metal compute shader or in Swift on cropped ROIs.
- A recommended hybrid: ML mask → dilate into an ROI → grey-level profile along the skeleton normal → sub-pixel edge (half-max or gradient peak) → width. This combines ML robustness with classical sub-pixel precision.

### Gaps
- No rigorous head-to-head benchmark of Frangi vs. CNN on the same pavement dataset was found.

## 5. Existing smartphone / mobile crack-width measurement projects and reported errors

### Takeaway
Published smartphone results cluster around ±0.5 mm width error, or sub-mm with calibration or reference targets. Fused camera+LiDAR research rigs claim <0.1 mm mean absolute error. Commercial apps (StructuraScan with ARKit+LiDAR+ML, Witteveen+Bos Crack Width Analysis) publish no independent accuracy data.

### Cited Findings
- Taiwanese Android crack-width app validated against a standard calibration plate: width deviations mostly −0.5 to +0.6 mm. — [Airiti thesis](https://www.airitilibrary.com/Article/Detail/U0020-2108202221494100); [MDPI Eng 6(6):122](https://www.mdpi.com/2673-4117/6/6/122)
- Mobile LiDAR apps on an RC beam: SMT-referenced scans about ±0.50 mm, unreferenced >1.5 mm. Canvas, RealityScan and Scaniverse gave the most accurate and homogeneous point distributions. — [Erciyes avesis](https://avesis.erciyes.edu.tr/publication/details/f02a9c53-16cf-4f97-8c6c-fcaa8f8e6632/oai)
- Smartphone LiDAR vs. TLS for building cracks: crack-length RMSE ±1.719 cm to ±2.201 cm (length, not width). — [UiTM record 2-s2.0-85203788019](https://update.library.uitm.edu.my/Record/2-s2.0-85203788019/Details)
- Camera+LiDAR fusion (DeepLabv3+ plus SAM refinement, VI-LiDAR SLAM): mean absolute width error <0.1 mm, mean relative error <15%. — [arXiv 2501.09203](https://arxiv.org/pdf/2501.09203)
- Laser-spot-scaled image method: width abs. error 0.02–0.57 mm. — [Applied Sciences 2023](https://doaj.org/article/30b8e36351044dbdbf2aac434e9b6ad8)
- Road crack type and size detection with a smartphone (NWPU). — [NWPU pure](https://pure.nwpu.edu.cn/en/publications/detecting-type-and-size-of-road-crack-with-the-smartphone/)
- Commercial: StructuraScan (iOS) claims ML + ARKit + LiDAR crack length/width measurement — [App Store](https://apps.apple.com/tr/app/structurascan/id6760573988); Witteveen+Bos Crack Width Analysis App (trained algorithm + AR) — [Witteveen+Bos](https://www.witteveenbos.com/digital-solutions/crack-width-analysis-app). Neither publishes accuracy.

### Inferences
- The most accurate approach is RGB (high-res) for width and LiDAR/ARKit only for scale and pose. LiDAR point clouds alone are about 1 cm resolution and cannot resolve crack width.
- A realistic product claim for an iPhone app at about 0.3 m with 12 MP stills is ±0.2–0.5 mm on cracks ≥0.5 mm, and "detected, <0.3 mm" for hairlines. Validate with a printed crack-width gauge or calibration plate, as the Taiwanese study did.

### Gaps
- No peer-reviewed study was found that specifically uses iPhone `captureHighResolutionFrame` plus LiDAR plane fitting for crack width. This pipeline appears novel or unpublished.
- The NWPU smartphone paper's error figures were not retrieved.
