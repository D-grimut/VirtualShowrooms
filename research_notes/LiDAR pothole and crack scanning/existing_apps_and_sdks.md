# Existing iOS 3D Scanning Apps, SDKs and Lightweight On-Device Reconstruction for Pothole / Crack Scanning

Research date: 2026-10-18. 15 tool calls were used (search plus fetch). Several items could not be sourced in that budget and are listed under Gaps. They are not filled in from memory.

## 1. What technique each popular scanning app uses, and published accuracy tests

### Takeaway
Consumer iPhone LiDAR apps fall into three camps:
- **LiDAR/ARKit depth meshing:** 3d Scanner App LiDAR mode, Polycam LiDAR mode, SiteScape, Canvas. Fast, works offline, centimetre-level accuracy.
- **Photogrammetry:** 3d Scanner App Photo Mode (Apple Object Capture), Polycam Photo mode (cloud), KIRI Engine (cloud).
- **Gaussian splatting:** Scaniverse (on-device), KIRI Engine (cloud), Luma (cloud), Polycam.

Independent tests consistently put smartphone LiDAR scans at about 1–3 cm at best, with large variation by app and by how the operator moves the phone. None of the apps showed millimetre-level accuracy. Road-infrastructure apps (Vialytics, RoadBotics) do not do 3D scanning: they use 2D video from a mounted phone plus AI classification.

### Cited Findings
**Independent accuracy studies**
- ISPRS 2026 study compared Polycam, PIX4Dcatch, KIRI Engine, Modelar and a research prototype (UC3D) against 253 coded targets surveyed with a Trimble X9 terrestrial laser scanner. The best result (UC3D) had 49.8 mm positional error. PIX4Dcatch was strong on distances within a single surface but less consistent across surfaces. Polycam and the other commercial apps showed more distortion between surfaces. Conclusion: smartphone LiDAR reaches centimetre-level accuracy, and results differ significantly by app. — [ISPRS Archives XLIX-M-1-2026](https://isprs-archives.copernicus.org/articles/XLIX-M-1-2026/1/2026/)
- Polytechnic of Bari 2022 (iPhone 12 Pro / iPad Pro 2021): "without scanning problems, the accuracies achievable … are ~1–3 cm". Surface splitting (double surfaces) and inertial-navigation drift were recurring problems. — [Smartphone LiDAR Technologies for Surveying (Poliba)](https://iris.poliba.it/retrieve/7da9a53f-82ec-4471-9402-88aec7532fe7/2022_Smartphone_LiDAR_Technologies_for_Surveying_pdfeditoriale.pdf)
- Askar & Sternberg 2023 (Geomatics) compared several iPhone apps on building facades. Accuracy varied greatly by app and by how the user moved the phone. — [Geomatics (DOAJ)](https://doaj.org/article/8c944a92436e4f40852802deb5b8e3d3)
- Modelar (Chase et al., 2022): about ±3 cm horizontal and ±7 mm vertical absolute accuracy against a control network (as summarised by search results; primary paper not fetched). — [Vilnius Tech journal](https://journals.vilniustech.lt/index.php/GAC/article/download/20797/12792)
- SAE 2025, Polycam on iPhone 15 scanning crashed vehicles: one dataset matched the reference well and others were less accurate. The authors call for further evaluation. — [SAE Mobilus](https://saemobilus.sae.org/papers/accuracy-mobile-phone-lidar-crashed-vehicles-2025-01-8692)
- A lab study of smartphone LiDAR across distances, lighting and materials reported absolute error below 1.1 mm and relative error at most 2.12%, under controlled conditions (search-result summary). — [Sensors and Materials SM4222](https://sensors.myu-group.co.jp/sm_pdf/SM4222.pdf)

**Pothole-specific work**
- A 2022 study in *Advanced LiDAR* measured potholes in Denizli (Pamukkale, Karahayıt) with iPhone 12+ LiDAR across four datasets. It concluded the method is a usable alternative for small road projects. — [Advanced LiDAR, Mersin Univ.](https://publish.mersin.edu.tr/index.php/lidar/article/view/465)
- A Wuhan University of Technology pothole point-cloud dataset was captured with an iPhone 14 Pro. It quotes sensor ranging accuracy of ±1–2% and a maximum range of about 5 m. — [IEEE DataPort: Small-scaled Pothole Point Clouds](https://ieee-dataport.org/node/15492)
- A 2025 ISPRS paper notes that such phone-based mapping solutions have limited accuracy. — [ISPRS XLVIII-4-W15-2025](https://isprs-archives.copernicus.org/articles/XLVIII-4-W15-2025/71/2025/isprs-archives-XLVIII-4-W15-2025-71-2025.pdf)

**Per-app techniques**
- **3d Scanner App (Laan Labs):**
  - Has LiDAR, TrueDepth (small detailed objects) and RoomPlan modes.
  - "Photo Mode" uses Apple's Object Capture photogrammetry API for finer detail on small objects.
  - Processing needs no signup, cloud or internet connection.
  - The App Store publisher now shows as "AI Photo Editor Lab SRL", so corporate ownership is unclear.
  - Sources: [App Store](https://apps.apple.com/us/app/-/id1419913995); [Digital Production 2020](https://digitalproduction.com/2020/10/07/3d-scanner-app-laan-lab/)
- **Polycam:**
  - LiDAR mode combines laser depth with photos and generates the mesh in real time.
  - Photo mode is photogrammetry: images are uploaded and built on Polycam's servers.
  - Gaussian splats are also offered.
  - Polycam itself claims "up to 98% accuracy" (vendor claim).
  - Sources: [Polycam blog: LiDAR vs Photogrammetry](https://poly.cam/blog/lidar-vs-photogrammetry-which-3d-scanning-method-is-right-for-you); [HKU 3D-scan guide](https://bookstack.hku.nl/books/3d-scan/page/polycam/export/pdf); [Polycam help: accuracy](https://learn.poly.cam/hc/en-us/articles/27488763119892)
- **Scaniverse (Niantic Spatial):**
  - Free, unlimited on-device 3D Gaussian splatting. Splats or meshes need no internet connection, and it works in airplane mode.
  - v5.2.0 (20 Feb 2026) added business accounts with cloud processing. These produce VPS maps, meshes and splats "optimized for Niantic Spatial SDKs".
  - Sources: [App Store](https://apps.apple.com/us/app/-/id1541433223); [Radiance Fields](https://radiancefields.com/scaniverse-introduces-gaussian-splatting); [Scaniverse release notes](https://www.nianticspatial.com/capture/scaniverse-release-notes)
- **Record3D:** Records and streams RGB-D (LiDAR or TrueDepth depth plus colour, with confidence maps since v1.10). It is a capture and streaming tool, not a fusion app. Live streaming is a paid in-app purchase. — [PyPI record3d](https://pypi.org/project/record3d); [App Store](https://apps.apple.com/jp/app/record3d-3d-videos/id1477716895)
- **SiteScape (now FARO):** LiDAR point-cloud capture for AEC with CAD outputs. Its accuracy claim is "accurate to the inch" (marketing, no tolerance given). The listing names iPhone 12–14 Pro and 2020–2022 iPad Pro. — search-result summary of the App Store listing; contemporary listing not fetched
- **Canvas (Occipital, apparently renamed "Twindo"):**
  - LiDAR scanning aimed at floor plans and CAD.
  - Occipital claims "up to 99%" measurement accuracy, and earlier claimed 1–2% for its non-LiDAR mode.
  - Graphisoft forum users report that fine details come out looking "hand-made".
  - Sources: [App Store](https://apps.apple.com/us/app/canvas-lidar-3d-measurements/id1169235377); [Graphisoft forum](https://community.graphisoft.com/t5/Collaboration-with-other/3D-scanning-of-as-built-with-Canvas-Structure-Sensor/td-p/255977/highlight/true); [Similarweb](https://similarweb.com/app/apple/1169235377)
- **KIRI Engine:**
  - Cloud photogrammetry and cloud 3DGS. Results take about 7–20 min after upload.
  - Its 3DGS Blender add-on is open source under Apache 2.0.
  - Has "3DGS to Mesh" conversion (v3.0 in KIRI 4.2).
  - Sources: [KIRI FAQ](https://www.kiriengine.app/faq/how-does-kiri-engine-process-the-files); [KIRI 3DGS feature](https://www.kiriengine.app/features/3d-gaussian-splatting); [Radiance Fields: Blender plugin v4.1](https://radiancefields.com/kiri-engine-releases-v4-1-of-free-3dgs-blender-plugin); [Radiance Fields: KIRI 4.2](https://radiancefields.com/kiri-engine-4.2-ships-3dgs-to-mesh-3.0)
- **Luma AI:** Cloud NeRF and Gaussian splatting from phone video. The company has pivoted to generative video (Dream Machine). Flythroughs were sunset on 1 Jan 2026, and capture uploads were temporarily paused in Nov 2024. Interactive Scenes (NeRF/3DGS) reportedly continue. — [Fast.io Luma review 2026](https://www.fast.io/resources/luma-ai-review-2026.md); [Radiance Fields Luma tag](https://radiancefields.com/tags/luma-ai)

**Road/infrastructure apps**
- **Vialytics:** a phone mounted in municipal vehicles records road images. A cloud AI detects cracks, potholes and, more recently, faded lane markings. Staff review the results in a web platform. — [Vialytics press release](https://www.mynewsdesk.com/de/vialytics/pressreleases/vialytics-expands-ai-powered-road-management-with-damaged-lane-marking-detection-3456345); [Traffic Technology Today](https://www.traffictechnologytoday.com/?p=13789)
- **RoadBotics:** a windshield-mounted phone records video plus GPS. AI classifies distresses (potholes, fatigue, longitudinal and transverse cracks) onto a 5-level colour map. Michelin acquired it in July 2022 for Michelin DDi. — [IEEE Spectrum](https://spectrum.ieee.org/cars-that-think/transportation/sensors/roadbotics-ai-could-change-the-way-cities-maintain-roads); [Technical.ly](https://technical.ly/startups/roadbotics-acquired-by-michelin)
- A 2017 academic Android app detected potholes and cracks with precision, recall and F-measure above 0.7. — [Roma Tre](https://iris.uniroma3.it/handle/11590/312719)

### Inferences
- Pothole depth (often 25–100 mm) is measurable with phone LiDAR to roughly ±1 cm, which may be enough for severity classes. Hairline floor and pavement cracks (sub-mm to a few mm wide) are below what any LiDAR-mesh app reliably resolves. They need high-res image analysis or photogrammetry instead.
- The commercial road apps' use of 2D imagery plus AI suggests the industry measures cracks by 2D detection and segmentation rather than 3D geometry at phone scale.
- No app publishes mm-level accuracy backed by an independent test. Vendor percentage claims (98%, 99%) are relative measurement errors and say nothing about mm detail.

### Gaps
- Not researched within budget, so technique and accuracy are unsourced: **Dot3D (DotProduct)**, **EveryPoint**, **Metascan**, **StreetScan**, and dedicated citizen pothole-reporting apps.
- Whether 3d Scanner App LiDAR "advanced" mode uses custom TSDF fusion or the raw ARKit scene mesh is not confirmed by a primary source.
- Current RoadBotics status inside Michelin after 2022 is unknown.
- No study compares iPhone depth inside potholes against a total station.

## 2. Embeddable SDKs and open-source components: status and licences

### Takeaway
Few maintained, embeddable, permissively licensed options exist:
- **StandardCyborgCocoa:** MIT, but the company no longer exists and the code is community-maintained only. It targets TrueDepth (front camera) for real-time fusion.
- **Record3D:** host-side C++/Python receive libraries rather than an iOS SDK.
- **Niantic Spatial SDK (NSDK):** reportedly offers Swift support (secondary source) but focuses on VPS and splats.
- **KIRI:** only its Blender add-on is open (Apache 2.0).
- **Apple RealityKit:** remains the only first-party, supported on-device reconstruction API (PhotogrammetrySession / ObjectCaptureSession).

### Cited Findings
- **StandardCyborgCocoa:**
  - MIT licence.
  - "All feature development, maintenance, and support is provided only by open source maintainers"; the company no longer exists.
  - StandardCyborgFusion does real-time 3D reconstruction with the TrueDepth sensor (iPhone X+, iPad Pro 2018+) and includes foot/ear ML models.
  - Use Swift Package Manager (the CocoaPods version is deprecated). No simulator support.
  - 196 commits, 7 open issues, 2 open PRs. No archived banner at fetch time.
  - Source: [GitHub StandardCyborg/StandardCyborgCocoa](https://github.com/StandardCyborg/StandardCyborgCocoa)
- **Record3D:**
  - Companion C++/Python library (`pip install record3d`) receives RGB-D streams from the Record3D iOS app over USB.
  - LiDAR support since 2020; confidence-map streaming since 2024 (needs app v1.10+).
  - It needs the paid Record3D app, so it is not an in-app SDK.
  - Sources: [PyPI record3d](https://pypi.org/project/record3d); [gittrend](https://gittrend.io/repo/marek-simonik/record3d)
- **Other LiDAR streaming:** kentaroy47/apple-lidar-stream (MIT) streams Apple LiDAR into Open3D. dora-ios-lidar (MIT) still depends on the Record3D app. — [ecosyste.ms](https://awesome.ecosyste.ms/api/v1/projects/github.com%2Fkentaroy47%2Fapple-lidar-stream); [dora README](https://ide-kyxt.pcl.ac.cn/dora-rs/dora/src/branch/main/node-hub/dora-ios-lidar/README.md)
- **Niantic Spatial / Scaniverse:** v5.2.0 lets users "deploy with NSDK" and "integrate via NSDK 4.0 for Unity, Swift, and Kotlin". This comes from a secondary APK-mirror listing and should be verified. The official release notes confirm outputs are "optimized for Niantic Spatial SDKs". — [APKMirror](https://www.apkmirror.com/apk/niantic-spatial-inc-2/scaniverse/); [Scaniverse release notes](https://www.nianticspatial.com/capture/scaniverse-release-notes)
- **KIRI Engine:** the 3DGS Blender add-on is open source under Apache 2.0. KIRI also said it would open-source the 3DGS-to-Mesh 2.0 code; the deadline was undated and fulfilment was not verified. — [Radiance Fields](https://radiancefields.com/kiri-engine-releases-v4-1-of-free-3dgs-blender-plugin); [Radiance Fields: 3DGS to Mesh 2.0](https://radiancefields.com/kiri-engine-3dgs-to-mesh-2-0-released)
- **Commercial measurement SDK example:** Vuforia documents using Apple Object Capture scans as Model Targets. This is a downstream use of Object Capture, not a measurement SDK. — [Vuforia library](https://library.vuforia.com:443/using-3d-scans/model-targets-apples-object-capture)

### Inferences
- StandardCyborgCocoa is the only ready-made iOS fusion codebase found. Because it targets TrueDepth (front camera, about 0.2–0.5 m working range), using it for rear LiDAR on pavement would need porting the depth input. Its maintenance risk is high.
- Practical in-house route: a custom Metal TSDF fusing ARKit `sceneDepth`/`smoothedSceneDepth` plus confidence with ARKit poses. Alternatively, record RGB-D plus poses (Record3D-style) and fuse off-device with Open3D.

### Gaps
- Record3D library licence not confirmed (the LICENSE file was not fetched).
- No sources gathered on Open3D iOS ports, COLMAP/OpenMVS compiled for iOS, a Laan Labs SDK, or commercial measurement SDKs. Their existence, licences (Open3D MIT, COLMAP BSD, OpenMVS AGPL are from general knowledge only and unverified here) and 2025–26 maintenance status are unknown from this research.
- Official Niantic NSDK 4.0 Swift documentation and licence terms were not fetched.
- Whether StandardCyborgFusion uses TSDF specifically is not stated on the README.

## 3. Lighter on-device photogrammetry / reconstruction alternatives

### Takeaway
On iOS, PhotogrammetrySession supports only the `.reduced` detail level. The roughly 4 GB free-storage requirement for ObjectCaptureSession is observed in logs (`required 4000000000`) and reported on Apple's forums, not documented by Apple. Lighter alternatives:
- **On-device Gaussian splatting (Scaniverse):** good visually, but hard to mesh and measure.
- **ARKit depth fusion:** fast, centimetre-level.
- **Depth mesh with photo texture:** fine detail exists only in the texture.
- **Using ARKit poses as priors** for multi-view stereo.

ARKit poses drift at centimetre level over long walks, which limits pose-only reconstruction.

### Cited Findings
- On iOS, only the `.reduced` detail level is supported, "optimized for generation and viewing entirely on mobile devices". Medium, full and raw are macOS-only. — [Apple docs: PhotogrammetrySession.Request.Detail](https://developer.apple.com/documentation/realitykit/photogrammetrysession/request/detail.md)
- iOS Object Capture (WWDC23) requires iOS/iPadOS 17+, a LiDAR device and an A14 or later chip. — [WWDC23 notes: Meet Object Capture for iOS](https://wwdcnotes.com/notes/wwdc23/10191)
- Storage: a January 2025 developer-forum report says ObjectCaptureSession fails with `insufficientStorage`, logging "required 4000000000" (about 4 GB). Apple's Reality Composer app behaves the same way. No official Apple figure was found. — [Apple Developer Forums: Storage for object capture](https://developer.apple.com/forums/thread/729249); [Object Capture forum tag](https://developer.apple.com/forums/tags/object-capture)
- The "4 GB" seen in WWDC21 material is a different requirement: a Mac GPU spec (Intel Macs with a 4 GB AMD GPU and 16 GB RAM). — [WWDC21 10076 notes](https://wwdcnotes.com/documentation/wwdc21-10076-create-3d-models-with-object-capture/)
- Apple staff advise fully tearing down the capture UI, and calling `finish()` and waiting for completion, before starting reconstruction on iOS, because both stages use heavy resources. — [Apple forum thread 761841](https://developer.apple.com/forums/thread/761841)
- PhotogrammetrySample can carry LiDAR depth into PhotogrammetrySession; one forum thread discusses how it is used. — [Apple forum thread 840946](https://developer.apple.com/forums/thread/840946)
- On-device splatting: Scaniverse makes splats and meshes fully offline. Splats suit specular, fuzzy or translucent surfaces but are "harder to convert into a mesh". — [Radiance Fields](https://radiancefields.com/scaniverse-introduces-gaussian-splatting); [HKU guide](https://bookstack.hku.nl/books/3d-scan/chapter/photogrammetry/export/html)
- Known ARKit poses:
  - Capture tools export an on-device COLMAP model from ARKit poses ("fast and deterministic, no feature matching"). — [Radiance Fields SplatKing pipelines](https://radiancefields.com/splatking/guide/pipelines)
  - COLMAP can triangulate from known poses as priors. — [Colmap-PCD arXiv](https://arxiv.org/pdf/2310.05504)
  - An RGBD-aided SfM built on COLMAP used ARKit LiDAR depth and poses. — [TMO arXiv 2303.15060](https://arxiv.org/pdf/2303.15060)
- A developer reports "several-centimetre discrepancies between observations of the same surfaces" over a longer ARKit walk and asks whether refined trajectories are exposed. — [Apple forum thread 842466](https://developer.apple.com/forums/thread/842466)

### Inferences
- For a pothole (under 1 m) captured in a short, closed loop, drift should be small. Using ARKit poses as priors for local multi-view stereo or bundle adjustment on full-res photos is likely the most accurate lightweight approach, but this is unverified.
- "Depth mesh plus high-res photo texture" is cheap in storage and processing. Crack width would then have to be measured in the 2D image (scaled by depth), not in the geometry.
- A small image count with `.reduced` detail probably needs far less memory than the full capture flow. Whether the ~4 GB storage check applies to PhotogrammetrySession used directly (without ObjectCaptureSession) is not established.

### Gaps
- No measured memory, storage or processing-time figures were found for iOS PhotogrammetrySession with about 20–40 images at `.reduced`.
- No official Apple statement of the storage requirement.
- No accuracy (mm) comparison of on-device splats versus LiDAR meshes for small surface defects.

## 4. Is offloading to a server or Mac common for millimetre accuracy?

### Takeaway
Yes, offloading is the dominant pattern for higher-detail results:
- Polycam Photo mode, KIRI Engine and Luma process in the cloud.
- Apple reserves medium, full and raw detail for macOS.
- Scaniverse added cloud processing for business accounts in 2026.

Still, no sourced evidence shows that phone capture plus server photogrammetry reaches mm accuracy on pavement defects.

### Cited Findings
- Polycam photogrammetry uploads images and builds the model on its servers. — [HKU Polycam guide](https://bookstack.hku.nl/books/3d-scan/page/polycam/export/pdf); [LiDAR News: Polycam Vision 25](https://lidarnews.com/polycam-vision-25-3d-reality-capture/)
- KIRI Engine processes uploads on cloud servers in about 7–20 minutes. — [KIRI FAQ](https://www.kiriengine.app/faq/how-does-kiri-engine-process-the-files)
- Apple: higher detail levels are macOS-only, and historically developers captured on iOS and reconstructed on a Mac. — [Apple docs](https://developer.apple.com/documentation/realitykit/photogrammetrysession/request/detail.md); [Apple forum 681871](https://developer.apple.com/forums/thread/681871)
- Scaniverse 5.2.0 added cloud processing for teams. — [Scaniverse release notes](https://www.nianticspatial.com/capture/scaniverse-release-notes)
- Vialytics and RoadBotics both run their AI in the cloud on phone-captured imagery. — [Traffic Technology Today](https://www.traffictechnologytoday.com/?p=13789); [IEEE Spectrum](https://spectrum.ieee.org/cars-that-think/transportation/sensors/roadbotics-ai-could-change-the-way-cities-maintain-roads)

### Inferences
- A hybrid design looks like the most practical path to near-mm detail: an on-device LiDAR or ARKit preview for immediate depth and area, plus optional upload of high-res photos and ARKit poses (and LiDAR depth) to a server running COLMAP or OpenMVS. Placing a scale reference (a known-size target) in frame would help validate results.

### Gaps
- No published mm-level accuracy figures for phone capture with server photogrammetry on potholes or cracks.
