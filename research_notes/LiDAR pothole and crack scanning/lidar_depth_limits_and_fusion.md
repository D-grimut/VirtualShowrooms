# iPhone/iPad LiDAR + ARKit depth: accuracy limits and on-device fusion for high-detail small-area models (potholes, cracks)

Research note scope: iOS 17–18+ Swift app, LiDAR devices (iPad Pro 2020+, iPhone 12 Pro – 16 Pro). Tool budget was limited, and several key papers (MDPI, Nature/PMC, Aalto thesis) returned 403 or captcha pages, so some mm-level numbers come from search-result summaries of those papers rather than full-text reads. These are flagged where relevant.

## 1. Specs of ARFrame.sceneDepth / smoothedSceneDepth (resolution, rate, confidence, range, noise) and measured accuracy studies

### Takeaway
ARKit delivers a 256x192 float32 depth map (meters) plus a 3-level confidence map, refreshed every frame, with a usable range up to about 5 m. Published accuracy studies consistently report about ±1 cm absolute accuracy for objects bigger than about 10 cm, about 1–2 cm RMSE for room-scale scans, and worse (several cm) for large or outdoor scenes. No peer-reviewed source I could reach gives a per-pixel depth-noise standard deviation in mm at 0.3–1.5 m.

### Cited Findings
- `ARDepthData.depthMap` is a CVPixelBuffer where "every pixel ... maps to a region of the visible scene (capturedImage), where the pixel value defines that region's distance from the plane of the camera in meters". `confidenceMap` "measures the accuracy of the corresponding depth data ... useful in filtering out lower-accuracy depth values". ARWorldTrackingConfiguration "exposes this depth information in the sceneDepth property which it updates every frame", enabled through the `.sceneDepth` frame semantic. Available from iOS/iPadOS 14.0. — [Apple: ARDepthData](https://developer.apple.com/documentation/arkit/ardepthdata)
- Confidence has three levels (`ARConfidenceLevel`: low/medium/high), stored as raw values 0/1/2 in an 8-bit buffer. Apple's sample shader reads `round(255*s.r)` and colours 0=red (least confident), 1=green, 2=blue (most confident). In Apple's illustration, desk and wall surfaces read as high confidence, window blinds as medium, and regions beyond the window as low. — [Apple sample: Displaying a point cloud using scene depth](https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth)
- Range: Apple's sample code comments that "The LiDAR Scanner supports a value no larger than 5.0" (meters). The sample also discards points with depth < 1.0 in its own display units. — [Apple sample](https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth)
- `smoothedSceneDepth` is a separate frame semantic. Apple's sample enables `[.sceneDepth, .smoothedSceneDepth]` together and lets the user toggle between raw and smoothed depth to compare them. Unity's ARKit docs describe it as "temporal smoothing" (`environmentDepthTemporalSmoothingRequested`). — [Apple sample](https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth); [Unity ARKit occlusion manual](https://docs.unity3d.com/Packages/com.unity.xr.arkit@6.0/manual/arkit-occlusion.html)
- Apple describes the depth map as "precise, low-resolution depth values". — [Apple sample](https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth)
- iPhone 14 Pro LiDAR depth maps are 256 × 192 and are reported as noisier and lower-resolution than dedicated RGB-D cameras (Azure Kinect, RealSense). That paper measures noise as pixel-wise L1 against rendered ground truth, not as a per-distance standard deviation. — [Huang et al., arXiv 2309.13570 (DTTD-Mobile)](https://arxiv.org/abs/2309.13570) (figure from the search summary; the abstract page has no numbers)
- The iPad Pro (2021) depth image is not raw ToF. It "fuses LiDAR data with color data through a machine learning algorithm to produce a depth image". Zea & Hanebeck analyse accuracy, precision, and temporal and spatial correlations against a Kinect 2 and note distance-dependent curvature artefacts. Numbers are in the full PDF, which I did not read. — [Zea & Hanebeck, JAIF 17(2), 2022, "Modeling Spatial Uncertainty for the iPad Pro Depth Sensor"](https://isif.org/media/66)
- **Luetzenburg, Kroon & Bjørk 2021 (Sci. Reports, iPhone 12 Pro / iPad Pro 2020):** "accurate high-resolution models of small objects with a side length > 10 cm with an absolute accuracy of ± 1 cm". A coastal cliff (130 × 15 × 10 m) reached ± 10 cm. Precision drops for objects smaller than 10 cm. — [Luetzenburg et al. 2021 (PMC)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8593014/); [DOAJ record](https://doaj.org/article/05f6da2bb22e4343bec5db6fcf0ecf88)
- **Vogt, Rips & Emmelmann 2021 (MDPI Technologies 9(2):25, iPad Pro LiDAR + TrueDepth vs industrial scanner, Lego bricks):** the industrial scanner "consistently delivered more accurate results", but smart-device accuracy "may already be sufficient, depending on the application". A 2022 ISPRS paper summarises the setup as a 300 mm distance at a 65° angle and says LiDAR scanning was judged impractical for small objects like Lego bricks. It reports a 0.16 mm average deviation, which most likely applies to the TrueDepth or industrial results rather than LiDAR; I could not verify this from the full text. — [Vogt et al. 2021 PDF](https://tore.tuhh.de/bitstream/11420/9247/1/technologies-09-00025.pdf); [ISPRS Archives XLIII-B4-2022-303 (summary)](https://isprs-archives.copernicus.org/articles/XLIII-B4-2022/303/2022/)
- **Spreafico et al. 2021 (ISPRS Archives XLIII-B1-2021-63, iPad Pro, outdoor emergency staircase):** precision about 0.02 m and accuracy about 0.04 m. The authors judged this suitable for architectural mapping at 1:200. — [ISPRS Archives XLIII-B1-2021/63](https://isprs-archives.copernicus.org/articles/XLIII-B1-2021/63/2021/) (numbers from the search summary)
- **Teppati Losè, Spreafico, Chiabrando & Giulio Tonolo 2022 (Remote Sensing 14:4157):** tested iPad Pro and iPhone 12/13 Pro with SiteScape, EveryPoint and 3D Scanner App in cultural-heritage scenes. The abstract notes that "3D positional accuracy and precision ... have not yet been fully validated". The full text (MDPI) returned 403, so I have no numbers. — [Remote Sensing 14(17):4157](https://www.mdpi.com/2072-4292/14/17/4157); [PoliTo IRIS](https://iris.polito.it/handle/11583/2972121)
- Another study reports iPad Pro LiDAR indoor point clouds at about 1–1.5 cm RMSE, against about 0.5 cm for a professional TLS. — [Comparative performance analysis of the iPad Pro LiDAR vs TLS (OHU repository)](https://acikerisim.ohu.edu.tr/items/d3d4a920-e7f5-42bf-88a4-5953b585f7a3) (from the search summary)
- SAE 2021: exterior vehicle measurements from iOS LiDAR scans were biased by up to 9.3 cm. — [SAE 2021-01-0891](https://saemobilus.sae.org/articles/bias-repeatability-measurements-3d-scans-made-using-ios-based-lidar-2021-01-0891)
- A 2024 study of iOS LiDAR apps found errors around 1 cm in some areas and up to about 10 cm in others. — [ISPRS Archives XLVIII-2-W8-2024-431](https://isprs-archives.copernicus.org/articles/XLVIII-2-W8-2024/431/2024/isprs-archives-XLVIII-2-W8-2024-431-2024.pdf) (from the search summary)
- A dataset paper (iPhone 14 Pro) quotes a maximum range of about 5 m and a ranging accuracy of "±1% to ±2%". That is a spec-style claim, not a validation. — [IEEE DataPort: Small-scaled Pothole Point Clouds](https://ieee-dataport.org/node/15492)
- An Apple Developer Forums post (anecdotal) reports that flat planes show heavy noise and sometimes "2-3 different planes". — [Apple Developer Forums thread 658213](https://developer.apple.com/forums/thread/658213)
- A 2025 Geodesy & Cartography paper evaluates iPhone 12 Pro, 13 Pro Max and 15 Pro Max LiDAR (including flat-surface tests) against geodetic references. Its numbers were not extractable. — [Geodesy and Cartography, DOI 10.3846/gac.2025.20797](https://journals.vilniustech.lt/index.php/GAC/article/download/20797/12792); [Geodetski vestnik 70/1 (Yanchuk)](https://geodetski-vestnik.com/arhiv/70/1/47_Yanchuk.pdf)

### Inferences
- If the ±1–2% ranging spec holds, the absolute range error is about 3–6 mm at 0.3 m, 5–10 mm at 0.5 m, and 10–20 mm at 1.0 m. This matches the "±1 cm on >10 cm objects" result. Absolute offset (bias) is less important for pothole depth than relative noise, because depth is measured relative to the surrounding pavement plane in the same scan.
- Because the depth image is ML-densified from a sparse emitter (Zea & Hanebeck), neighbouring depth pixels are spatially correlated. Their effective independent resolution is lower than 256x192, and averaging neighbouring pixels does not reduce noise as much as it would for independent samples.

### Gaps
- Frame rate: commonly quoted as 60 Hz (matching the ARKit camera frame rate, per WWDC20 "Explore ARKit 4"), but I did not confirm it from a source in this session. Measure it at runtime from `ARFrame.timestamp` deltas for frames with non-nil `sceneDepth`.
- Exact per-pixel noise σ (mm) at 0.3 / 0.5 / 1.0 / 1.5 m was not found in any accessible source. The candidates are the Zea & Hanebeck full PDF, the Aalto 2021 thesis characterising the iPad Pro 2020 depth sensor ([Aalto doc](https://aaltodoc.aalto.fi/server/api/core/bitstreams/3e6fc65b-6e0e-4471-9e25-6b27c8f31d72/content), which returned 403) and GAC 2025.
- The numeric results of Teppati Losè et al. 2022 were not retrieved.
- Emitter spot count: the LiDAR is widely reported to project a sparse dot array (often quoted as 24×24 = 576 spots, with the 256x192 map interpolated or ML-filled from them). I found no citable source in this session, so treat this as unverified.

## 2. ARMeshAnchor mesh resolution vs raw depth: why it is coarse

### Takeaway
I found no Apple-documented vertex spacing for ARMeshAnchor. It is a real-time, room-scale reconstruction built for occlusion and physics, fused from the same 256x192 depth. It is therefore smoothed and decimated well below what the raw depth can resolve, even though the raw depth itself is only cm-level accurate.

### Cited Findings
- Scene reconstruction meshes and sceneDepth both come from the same LiDAR depth stream. The depth map is described as "low-resolution" by Apple, and the sample uses a guided filter just "to create the illusion of a high-resolution depth map". — [Apple sample](https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth)
- Third-party apps (SiteScape, EveryPoint, 3D Scanner App) that export point clouds from raw depth are what researchers evaluate for accuracy. They do not use ARMeshAnchor meshes. — [Teppati Losè et al. 2022 (abstract)](https://www.mdpi.com/2072-4292/14/17/4157)

### Inferences
- Developer reports commonly describe ARMeshAnchor triangle edges at roughly several cm. That figure is unverified here. The mesh is built for whole-room coverage at 60 Hz with bounded memory, so fine detail is sacrificed by design. Building your own fusion from `sceneDepth` with a small voxel (for example 2–5 mm) over a 1 m² region is the standard way past it.

### Gaps
- Official ARMeshAnchor voxel/vertex spacing was not found. Measure it empirically by computing the mean edge length of `ARMeshGeometry` faces on a flat floor.

## 3. Ground sampling distance (mm per depth pixel) at 0.3 / 0.5 / 1.0 m, smallest resolvable step, and whether LiDAR can detect 1–10 mm cracks

### Takeaway
Depth-pixel footprint is about 1.5 mm at 0.3 m, about 2.6 mm at 0.5 m and about 5 mm at 1.0 m. That is computed, and the true independent sampling is coarser. Combined with ±(1–2)% range error and ML smoothing, LiDAR depth alone cannot detect 1–10 mm-wide cracks. It can measure pothole depth and volume at roughly the cm level, or a few mm after fusion. Cracks must come from the RGB image.

### Cited Findings
- Unprojection used by Apple: `x = (u − cx)·d/fx`, `y = (v − cy)·d/fy`, `z = d`, using `cameraIntrinsics`. The intrinsics are given for the captured image, so they must be scaled to the depth-map size. — [Apple sample](https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth)
- Luetzenburg et al.: precision degrades for objects with a side length < 10 cm, and the absolute accuracy is ±1 cm. — [Luetzenburg et al. 2021](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8593014/)
- Vogt et al. (as summarised by ISPRS 2022): LiDAR judged impractical for small objects like Lego bricks at 300 mm. — [ISPRS 2022 summary](https://isprs-archives.copernicus.org/articles/XLIII-B4-2022/303/2022/)
- Pothole studies with iPhone LiDAR: a 2022 Denizli (Turkey) study used region growing plus plane fitting and calls iPhone 12+ LiDAR an "alternative measurement technique for small road projects" (no error quantified). An iRodd smartphone-LiDAR pothole volume study reports 5.35% average volume error and 6.47 mm RMSE against reference. Khan & Kumar (2026) use polynomial-regression stack profiles. None of them addresses crack width. — [Mersin LiDAR journal 2022](https://publish.mersin.edu.tr/index.php/lidar/article/view/465); [civilejournal.org](https://civilejournal.org/index.php/cej/article/download/5954/1890/16240); [synapsesocial (Khan & Kumar)](https://www.synapsesocial.com/papers/69a75b05c6e9836116a21988)

### Inferences (computed, verify with runtime intrinsics)
- Typical ARKit wide-camera intrinsics at 1920×1440 give fx ≈ 1,450–1,600 px (an assumption; read `frame.camera.intrinsics` on the device). Scaled to 256 px width, fx_depth ≈ 195–215 px. The pixel footprint is GSD ≈ d / fx_depth:
  - 0.3 m: about 1.4–1.5 mm/pixel
  - 0.5 m: about 2.3–2.6 mm/pixel
  - 1.0 m: about 4.7–5.1 mm/pixel
  - For the RGB image at 1920×1440, divide by about 7.5: about 0.2 mm/pixel at 0.3 m and 0.65 mm/pixel at 1.0 m. At 4K (3840×2880 class, via high-res capture) it is about 0.1–0.35 mm.
  - Coverage at 0.5 m: a 256-pixel row spans about 0.6–0.65 m, so one frame covers about 0.6×0.5 m.
- The true lateral resolution is worse than the pixel footprint, because the depth image is densified from a sparse emitter grid (unverified spot count; see Gaps in section 1) and ML-smoothed.
- Smallest depth step: with ±1–2% range error (5–10 mm at 0.5 m) and per-frame noise of likely several mm, single-frame depth steps under about 5–10 mm are not reliably resolvable. Fused multi-frame data might resolve about 2–5 mm steps on smooth surfaces (an inference; there is no measured source).
- Cracks 1–10 mm wide: a 1–3 mm crack is smaller than one depth pixel even at 0.3 m, and it is smoothed out by the ML densification. A 5–10 mm crack spans only 2–7 depth pixels at 0.3 m (1–2 at 1 m), and its depth signal is smoothed away. The conclusion is that LiDAR depth alone cannot detect 1–10 mm cracks. The RGB image (0.1–0.6 mm/pixel) is the right channel for crack detection and width, with LiDAR supplying scale and the surface plane.

### Gaps
- No peer-reviewed measurement of the iPhone LiDAR modulation transfer or minimum detectable step height was found.

## 4. Fusing depth on device: Apple point-cloud sample, TSDF/voxel fusion on iOS, marching cubes, beating single-frame noise, pose drift

### Takeaway
Apple's sample gives the Metal pipeline for depth unprojection, confidence filtering and RGB colouring (and an earlier version accumulated points over time). TSDF fusion with marching cubes is not provided by Apple, and I found no well-known, maintained Swift/Metal TSDF library. You port a reference TSDF (andyzeng/tsdf-fusion, vdbfusion) to Metal compute. For a 1 m² patch, a dense 2–4 mm grid is small enough for memory on modern iPhones, and multi-frame fusion should reduce random noise. Systematic bias, ML smoothing and pose drift set the floor.

### Cited Findings
- Apple's "Displaying a point cloud using scene depth" sample:
  - wraps depth as an `r32Float` Metal texture and the camera image as Y (`r8Unorm`) plus CbCr (`rg8Unorm`) textures;
  - unprojects each depth pixel in a vertex shader using camera intrinsics;
  - filters by confidence (`confFilterMode`);
  - colours each point from capturedImage;
  - toggles smoothed depth;
  - can upsample depth with `MPSImageGuidedFilter` plus `MPSImageBilinearScale`.
  - The WWDC20 "Explore ARKit 4" (session 10611) version accumulated points into a persistent cloud. That version is in the initial commit of the sample's Git repo.
  — [Apple sample](https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth)
- Reference TSDF implementations: andyzeng/tsdf-fusion (CUDA, "fuse multiple registered depth maps into a projective TSDF voxel volume") and tsdf-fusion-python; PRBonn vdbfusion (sparse VDB-based TSDF, C++/Python); intbots/cpu_tsdf (CPU, octree, includes marching cubes). None of them targets iOS. — [RobotLocomotion/tsdf-fusion](https://github.com/RobotLocomotion/tsdf-fusion); [PRBonn/vdbfusion](https://gittrend.io/repo/PRBonn/vdbfusion); [intbots/cpu_tsdf](https://github.com/intbots/cpu_tsdf)
- iOS-side references: Reality-Synthesizer (Metal shaders on LiDAR depth; notes that iOS 15.4 opened LiDAR to AVFoundation via `builtInLiDARDepthCamera`), which does no TSDF; the WWDC20 sample code mirror ("Creating a fog effect using scene depth"). — [robomex/Reality-Synthesizer](https://github.com/robomex/Reality-Synthesizer); [artemnovichkov/wwdc20-samplecode](https://github.com/artemnovichkov/wwdc20-samplecode/blob/master/CreatingAFogEffectUsingSceneDepth)
- My searches found no ready-made open-source Swift/Metal voxel-hash TSDF for ARKit. — (negative result from searches in this session)

### Inferences
- Memory budget for a dense TSDF over a 1.0 × 1.0 m area × 0.2 m height:
  - 4 mm voxels: 250×250×50 ≈ 3.1 M voxels. At float16 TSDF + float16 weight + RGB8 (about 7–8 B per voxel), that is about 25 MB.
  - 2 mm voxels: 500×500×100 = 25 M voxels, about 200 MB.
  - Both are feasible on 6–8 GB iPhone Pros, but 2 mm is heavy. A 3 mm grid is about 60 MB. A sparse or hashed grid restricted to near the ground plane cuts memory further.
  - Integration of 256×192 = 49k depth pixels per frame (or a per-voxel projective pass) is trivial for an Apple GPU at 30–60 Hz.
  - Run marching cubes (or a heightfield mesh, since ground is 2.5D) once at export.
- Fusion vs noise: averaging N roughly independent observations reduces random noise by about √N, so 30–100 frames could take several-mm noise down to the sub-mm or ~1–2 mm level. However:
  - neighbouring pixels are correlated by ML densification;
  - consecutive frames from a near-static pose are correlated;
  - range bias of ±1–2% does not average out.
  Expect fused relative accuracy of roughly 2–5 mm on a pavement patch (an inference, not measured). Varying the viewpoint helps decorrelate the errors.
- A strong simplification for ground patches: fit the pavement plane (RANSAC), then fuse depth into a 2.5D heightmap (for example a 2 mm grid aligned to the plane), using a weighted running mean with confidence and incidence-angle weights. This is cheaper than a 3D TSDF and produces depth and volume directly.
- Pose drift: ARKit VIO drift over a 1 m², roughly 10–30 s scan is generally small (mm to low cm). This is not quantified by any source I found. It can blur the fusion at the mm level, so keep scans short. Optionally refine each frame with ICP (point-to-plane against the current model) before integrating.

### Gaps
- No measured ARKit pose-drift figures (mm per m) were found in this session.
- No benchmarks (memory or fps) for Metal TSDF on iPhone were found.

## 5. RGB-guided depth upsampling, and captureHighResolutionFrame and its interplay with depth

### Takeaway
Apple itself demonstrates guided-filter depth upsampling (MPSImageGuidedFilter), but calls the result an "illusion" of resolution. It sharpens edges to match the RGB image but adds no true depth information. ARKit 6 / iOS 16+ `captureHighResolutionFrame` gives an out-of-band, high-resolution capturedImage with pose and frame semantics populated. That makes it the right input for crack detection and texturing, while geometry stays at LiDAR resolution.

### Cited Findings
- Apple: "To create the illusion of a high-resolution depth map, the sample app offers UI to enlarge the depth map using Metal Performance Shaders ... By filling in gaps in the framework's depth information, the enlarged depth buffer creates the illusion of more depth information." It uses `MPSImageGuidedFilter(device:kernelDiameter:)` with RGB as the guide and `MPSImageBilinearScale` for the confidence map. — [Apple sample](https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth)
- `ARSession.captureHighResolutionFrame(completion:)` and its async variant are available on iOS/iPadOS 16.0+. Details:
  - it "Requests a frame outside of the normal frequency that contains a high-resolution captured image";
  - "ARKit populates the frame's properties other than pixel data, including pose information, anchors, and frame semantics";
  - it is delivered out-of-band without disturbing the regular frames;
  - it fails with `highResolutionFrameCaptureInProgress` if a capture is already in progress, or with `highResolutionFrameCaptureFailed`;
  - for the highest resolution, choose a non-binned `videoFormat` with `isRecommendedForHighResolutionFrameCapturing`, or use `recommendedVideoFormatForHighResolutionFrameCapturing`.
  — [Apple: captureHighResolutionFrame](https://developer.apple.com/documentation/arkit/arsession/capturehighresolutionframe(completion:))

### Inferences
- Because "frame semantics" are populated, the high-res frame should carry `sceneDepth` from the nearest depth sample. Verify this on device, since depth stays at 256x192 regardless.
- Joint bilateral or guided upsampling is useful for cleaner edges (pothole rims) and for assigning per-RGB-pixel depth for texturing. It cannot recover sub-pixel depth features such as crack depth.
- A practical pipeline is LiDAR for metric geometry and the plane, plus high-res RGB keyframes (0.1–0.3 mm/pixel) projected onto the fused heightmap. Run crack segmentation in 2D (for example Core ML) and measure width in mm using the known depth and intrinsics.
- If the app is willing to compute a small amount of multi-view stereo or shape-from-shading on a few keyframes, that could add mm detail. That is still far lighter than Object Capture, but untested.

### Gaps
- Whether `captureHighResolutionFrame` blocks or drops depth frames, and its exact resolutions per device (for example 12 MP or 48 MP on iPhone 14 Pro+ in 4K formats), were not confirmed in this session. The WWDC22 "Discover ARKit 6" session (4K video formats, high-res capture) was not fetched.
- AVFoundation `builtInLiDARDepthCamera` (iOS 15.4+) depth resolution and rates outside ARKit were not confirmed.

## 6. Best practical scanning settings: distance, speed, lighting, angle

### Takeaway
The evidence base is thin. The best-supported rule is that accuracy degrades with distance (±1–2% range error) and objects below about 10 cm lose precision. For a pothole, scan at about 0.3–0.6 m, near-nadir with some oblique passes, slowly, over a short session. Prefer high-confidence pixels only.

### Cited Findings
- Range error scales with distance (±1–2% quoted). — [IEEE DataPort pothole dataset](https://ieee-dataport.org/node/15492)
- Vogt et al. scanned at 300 mm at a 65° angle (as summarised). — [ISPRS 2022 summary](https://isprs-archives.copernicus.org/articles/XLIII-B4-2022/303/2022/)
- The confidence map flags low-accuracy regions (in Apple's example, distant and thin structures such as blinds have medium or low confidence), so filter for high confidence. — [Apple sample](https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth)
- App choice matters: results varied across SiteScape, EveryPoint and 3D Scanner App, and across scene types (about 1 cm in some areas to about 10 cm in others). — [Teppati Losè et al. 2022](https://www.mdpi.com/2072-4292/14/17/4157); [ISPRS 2024](https://isprs-archives.copernicus.org/articles/XLVIII-2-W8-2024/431/2024/isprs-archives-XLVIII-2-W8-2024-431-2024.pdf)

### Inferences
- Distance: about 0.3–0.5 m gives the finest depth footprint (about 1.5–2.6 mm) and the smallest absolute range error. Below about 0.25–0.3 m, LiDAR depth tends to become unreliable (a commonly reported near limit, unverified) and the field of view shrinks.
- Angle: favour near-perpendicular views of the pavement for depth, plus a ring of oblique (about 30–45°) views to capture pothole walls. Grazing angles (> 60° from the normal) reduce ToF return quality.
- Speed: move slowly (for example < 0.2 m/s) to limit motion blur in RGB and to keep VIO stable. Keep the total scan to about 10–30 s to limit drift.
- Lighting: ToF depth is active, so it works in the dark, but VIO tracking and RGB texture need adequate, diffuse light. Strong direct sunlight adds ambient IR noise and may reduce LiDAR range and confidence outdoors (plausible, but not quantified here). Wet or specular surfaces (water in potholes) give bad returns.
- Weighting: use only `.high` confidence pixels, weight each sample by cos(incidence) and by 1/d², and discard pixels near depth discontinuities.

### Gaps
- No controlled study quantifying the effects of scan speed, sunlight or incidence angle on iPhone LiDAR was retrieved.
