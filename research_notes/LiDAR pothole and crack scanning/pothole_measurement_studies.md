# Pothole and Pavement Distress Measurement with Smartphone/Tablet LiDAR and Low-Cost Depth Sensors

Research date: 2026-10-18. Searches covered ~20 tool calls. Many full texts were paywalled or not machine-readable; figures below come from abstracts or PDFs that could be extracted. Where only an abstract was available, this is noted.

## Q1. Studies using iPhone/iPad LiDAR (and Kinect/RealSense) for potholes and surface damage: devices, distances, errors vs ground truth

### Takeaway
The evidence is mixed. Lab and small-object studies report about 1 cm absolute accuracy for iPhone LiDAR and 5-10% pothole volume error. A Mineta Transportation Institute (MTI) field study against a Leica P20 terrestrial laser scanner (TLS) found that iPad and iPhone scans could not resolve vertical deformations under 3-4 cm, and that drift appeared on longer scans. Close-range, short, single-pothole scans are therefore viable. Long walking scans of road sections are not. Depth (z) error is consistently the weakest axis, and it tends toward overestimation.

### Cited Findings
**Study table (device / distance / ground truth / error)**

- **Beavers, Day, Krietemeyer, Peterson, Ahn, Li (2024), MTI Report 24-16 / CA-MTI-2224.**
  - Devices: Apple iPad Pro and iPhone Pro (12 and later) LiDAR, used with free apps (3D Scanner App).
  - Ground truth: Leica P20 TLS surface as the "truth" model.
  - Findings: best-case resolution about 1 cm. The scans "could not detect smaller cracks and shallow potholes". The authors conclude the approach "falls short of providing the necessary resolution and accuracy required" for roadway damage assessment. — [ROSA P record](https://rosap.ntl.bts.gov/view/dot/75721)
- **MTI research brief, same project.**
  - "Vertical deformations in surfaces less than 3-4 cm were not identifiable using both the iPad and the iPhone."
  - "Scans over larger areas exhibited misalignments of the measured data, leading to inaccurate surface models."
  - 2D detail aided by photo overlay was "comparable to that of conventional cameras."
  - The device relies heavily on its IMU (inertial measurement unit), camera and single-frequency GNSS for positioning.
  - Distresses were classified per the Caltrans Pavement Distress Manual.
  - Suggested improvements: gimbal stabilisers and PC-based processing of raw data.
  - [MTI brief PDF](https://transweb.sjsu.edu/sites/default/files/2224-RB-Peterson-LiDAR-Surface-Texture-Assessment.pdf); [ROSA P](https://rosap.ntl.bts.gov/view/dot/75721)
- **Adi, Suprobo, Waliulu (2024), "iRodd", J. Infrastructure Policy & Development 8(11).**
  - Device: "LiDAR smartphone" (model not stated in abstract), with a detection model.
  - Error: average pothole volume error of 5.35% against reference data; RMSE of 6.47 mm.
  - Scanning distance and algorithm are not in the abstract. The authors cite related earlier work (Waliulu et al., 2023) on volume accuracy with low-cost LiDAR.
  - [JIPD article](https://systems.enpress-publisher.com/index.php/jipd/article/view/6162)
- **Vogt, Ilic, Bogenberger (2023), J. Location Based Services 17(4):389-411 (TUM).**
  - Device: handheld low-cost consumer LiDAR with the 3D Scanner App, scanned at low walking speed.
  - Detected potholes and bumps.
  - MAPE (mean absolute percentage error): x 3.53%, y 4.43%, z 10.57%. The higher z error indicates "overestimation of infrastructural damage depth."
  - The ground truth method was not stated on the abstract page.
  - [TUM portal](https://portal.fis.tum.de/en/publications/a-mobile-mapping-solution-for-vru-infrastructure-monitoring-via-l/)
- **Khan and Vasantha Kumar (2026), "Use of Apple iPhone LiDAR for geometric measurement of road potholes using polynomial regression based stack profile method".**
  - Only an aggregator summary was found; no accuracy numbers.
  - [Synapse summary](https://www.synapsesocial.com/papers/69a75b05c6e9836116a21988)
- **Same authors (2025), Civil Engineering Journal: LiDAR (TLS) pothole patching quantity with a segmented TIN model.**
  - The traditional cuboid (L x W x D) volume estimate was 2-4x larger than the LiDAR TIN-based volume.
  - [CEJ article](https://civilejournal.org/index.php/cej/article/view/5954)
- **iPhone LiDAR stack-profile volumes on streambed (fluvial) potholes, listing only.**
  - Extracted length, width, depth, area and volume, compared against a Leica BLK360.
  - MAPE below 10%.
  - Venue and full text were not verified.
  - [ResearchGate listing](https://www.researchgate.net/publication/370217474_Evaluating_Apple_iPhone_LiDAR_measurements_of_topography_and_roughness_elements_in_coarse_bedded_streams)
- **Luetzenburg, Kroon, Bjørk (2021), Scientific Reports. Baseline iPhone 12 Pro LiDAR accuracy.**
  - Objects with side length over 10 cm: ±1 cm absolute accuracy.
  - Large scenes (130 x 15 x 10 m cliff): ±10 cm.
  - Reference: SfM-MVS (structure-from-motion multi-view stereo photogrammetry).
  - [PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8593014/)
- **IEEE DataPort "Small-scaled Pothole Point Clouds".**
  - 591 potholes captured with iPhone 14 Pro LiDAR and Polycam.
  - Quoted sensor spec: range up to 5 m, ranging accuracy ±1-2%.
  - [IEEE DataPort](https://ieee-dataport.org/node/15492)
- **Rauf Butt et al. (2026), PLOS ONE.**
  - Used iPhone 14 Pro LiDAR depth maps as training ground truth for monocular RGB pothole depth.
  - Validated with a laser rangefinder (±1 mm precision) on 500 potholes, at 5 points each.
  - Capture setup: heights 0.5-4 m, pitch 15-75°, 25% of captures on wet roads.
  - The authors note that LiDAR reliability drops on "highly reflective, glossy, or dark materials" such as wet roads, and that effective range is under 5 m.
  - No iPhone-vs-manual MAE was found in the extracted text.
  - [PLOS ONE](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0344604)
- **Kamal et al. (2018), Int. J. Pavement Engineering (Aston). Kinect v2 on artificial potholes in clear, muddy and oily water.**
  - Mean percentage error 2.58% (depth) and 5.47% (volume).
  - Also handles stones and pebbles that appear as negative depth.
  - [Aston Research Portal](https://research.aston.ac.uk/en/publications/performance-assessment-of-kinect-as-a-sensor-for-pothole-imaging-/)
- **Yurdakul and Taşdemir (2025), arXiv 2505.04207. Intel RealSense D415 RGB-D with a YOLOv8-seg variant (PothRGBD dataset, 1000 images).**
  - On 5 test images:
    - Perimeter error ranged from -3.2 to +1.7 cm (mean about ±2.3 cm).
    - Depth error ranged from -0.2 to +0.3 cm (mean about ±0.24 cm).
  - Reference: camera height is estimated as the median depth of the pothole-free surface region. This compensates for vehicle and suspension motion.
  - [arXiv](https://arxiv.org/pdf/2505.04207v1)
- **Other low-cost sensors.**
  - A RealSense D455 surface-profiling study concluded the approach is usable for road profiles if about ±1 cm accuracy is acceptable over strips of about 50 cm or less.
  - A depth camera with YOLOv8 study reported about 5 mm average depth error.
  - A stereo dash-camera project reported about 82% depth error on real potholes.
  - All three are from search snippets only. — [Search results incl. arXiv/USF/UAEMex](https://digitalcommons.usf.edu/fcrar/2022/may12/12); [UAEMex](https://cienciaergosum.uaemex.mx/article/download/22933/19063/); [TARC stereo](https://eprints.tarc.edu.my/276)
- **Anggoro et al. (2019), SPIE.** Digital image correlation on artificial potholes (5-25 cm diameter, 6-12 cm deep): under 7% error, depth resolution 0.43 cm. — [doi](https://doi.org/10.1117/12.2573129)
- **Krausková et al. (2025), Sensors.** iPhone 14 Pro streambed survey: vertical RMSE 0.16 m with reference points every 20 m. This shows how errors grow over large areas. — [MDPI Sensors](https://www.mdpi.com/1424-8220/25/19/6141)

### Inferences
- Realistic iPhone/iPad LiDAR targets for a single pothole scanned close-up are:
  - depth error roughly 3-10 mm (RMSE 6.47 mm in iRodd; ±1 cm in Luetzenburg);
  - volume error about 5-10%;
  - footprint (x/y) error about 3-5%.
- Depth is the weakest axis and tends to be overestimated, so the app should report depth with a ±1 cm uncertainty band.
- The MTI negative result (deformations under 3-4 cm not seen) came from area-scale walking scans processed by the 3D Scanner App. It is not directly comparable to a single-pothole ARKit scene-depth capture. The finding still warns against long scan paths and against trusting depths under 13 mm.
- Volume comparisons against a "cuboid" manual estimate will look badly off, because manual L x W x D overstates volume 2-4x (Khan and Kumar). Ground truth should be sand or water fill, or TLS.

### Gaps
- No full text was obtained for iRodd, Khan and Kumar 2026, or Vogt et al. Missing details:
  - device model (for iRodd);
  - scanning distance;
  - ground-truth method;
  - exact algorithm.
- No study was found that systematically varied the iPhone-to-pavement distance for potholes.
- No iPad/iPhone LiDAR study of spalling or rutting with mm-level error numbers was found.

## Q2. Standard pothole quantification algorithm, variants and pitfalls

### Takeaway
The proven pipeline is:
1. Crop the scan around the pothole.
2. Fit a reference surface to the intact pavement (RANSAC plane, least squares, or the median of pothole-free depths).
3. Compute signed depth below that surface.
4. Segment the pothole by a depth threshold or Otsu binarisation.
5. Take the area from the projected footprint (convex hull, or a cell count on a grid).
6. Compute volume as the integral of depth over grid cells, or as TIN (triangulated irregular network) prisms.

Crowned roads, low inlier ratios and debris are the main pitfalls. Variants add a quadratic or parabolic road model, or a cloth-simulation datum.

### Cited Findings
- **Kinect (patent).** Fit a plane to the road surface and subtract the depth data from that plane. Binarise the result with an Otsu-derived threshold (about 0.35 on a normalised histogram), then place a bounding box on the defect. — [US Patent 9196048](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9196048)
- **RealSense D415 study.**
  - Reference level: the median depth of pothole-free regions.
  - Depth: reference minus pothole depth.
  - Perimeter: segmentation contours converted to physical units.
  - [arXiv 2505.04207](https://arxiv.org/pdf/2505.04207v1)
- **Binocular point cloud.** Project the pothole points onto the road plane, triangulate them, restore their true elevations, and sum the volumes of the triangular prisms. — [Hindawi / IDEAS record](https://ideas.repec.org/a/hin/jnlmpe/9157849.html); [Laser & Optoelectronics Progress 2025](https://www.researching.cn/articles/OJ7d2cc5e37e86884d/figureandtable)
- **Segmented TIN volume on TLS points (Khan and Kumar 2025).** — [CEJ](https://civilejournal.org/index.php/cej/article/view/5954)
- **Stack-profile method.**
  - Slice the pothole into parallel cross-section profiles.
  - Fit a polynomial regression to each profile.
  - Integrate across the slices.
  - Used in the 2026 Khan and Kumar iPhone paper and in the streambed iPhone pothole work.
  - [Synapse](https://www.synapsesocial.com/papers/69a75b05c6e9836116a21988); [ResearchGate](https://www.researchgate.net/publication/370217474_Evaluating_Apple_iPhone_LiDAR_measurements_of_topography_and_roughness_elements_in_coarse_bedded_streams)
- **RANSAC caveat.** The fit depends on the ratio of plane points to total points in the region of interest, so large potholes in a small crop degrade the fit. — [Gdańsk Univ. of Technology](https://pub.pg.edu.pl/en/publication/140400/applying-ransac-algorithm-for-fitting-scanning-strips-from-airborne-laser-scanning)
- **Crowned roads.** Fit a quadratic parabolic arched pavement model per cross-section, and fit the arch twice to separate potholes from normal pavement. — [ASCE CICTP 2021](https://ascelibrary.com/doi/10.1061/9780784483565.045)
- **Cloth-simulation datum vs RANSAC (2025).** RANSAC-based pothole extraction precision was 66.0%, against 87.5% for the cloth-simulation datum. — [Laser & Optoelectronics Progress 62(2) 2025](https://www.researching.cn/articles/OJ7d2cc5e37e86884d/figureandtable)
- **Student pipeline (illustrative, not validated).** Voxel downsampling, then statistical outlier removal, then RANSAC plane segmentation, then DBSCAN, then a convex hull for dimensions. — [SlideShare](https://www.slideshare.net/slideshow/a-hybrid-method-for-pothole-depth-estimation-ppt-6-2-pptx/283475376)
- **Water and debris.** Kamal et al. tested clear, muddy and oily water in the holes. Stones and pebbles show up as negative depth (above the plane) and must be handled. — [Aston](https://research.aston.ac.uk/en/publications/performance-assessment-of-kinect-as-a-sensor-for-pothole-imaging-/)
- **Wet and dark surfaces.** Glossy or dark surfaces such as wet roads reduce iPhone LiDAR reliability. — [PLOS ONE 2026](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0344604)
- **Severity thresholds.** Pothole severity starts at 13 mm depth, and depression and rutting thresholds start at 6-13 mm (see Q3). This supports a segmentation depth threshold of about 13 mm, which is also about the sensor noise floor. — [TotalPave PCI training (from ASTM D6433)](https://totalpave.com/wp-content/uploads/2021/11/PCI-Asphalt-Distress-Training.pdf)

### Inferences
Recommended pipeline for an iOS app (synthesised from the above):
1. Fit the reference surface on a ring around the hole, roughly 0.3-0.5 m beyond the visible edge, excluding the hole.
   - Use RANSAC with an inlier tolerance of about 5-10 mm, matched to the about 1 cm sensor noise.
   - Refine the RANSAC result with least squares on its inliers.
   - Optionally fit a quadratic surface to absorb crown and cross slope. A 2% cross slope over a 1 m crop is 20 mm of tilt, which a plane absorbs but a crown curvature does not.
2. Rasterise the signed depth onto a 5-10 mm grid.
3. Segment the pothole as connected cells deeper than the threshold. Use 13 mm to match the PCI minimum; a sensitivity mode at 6-10 mm is optional.
   - Clip negative depths (debris) to 0.
4. Compute the outputs:
   - Area: cell count x cell area.
   - Volume: sum of depth x cell area.
   - Max depth: use a high percentile (for example the 98th-99th), not the single deepest point, to reject outlier spikes.
   - Mean depth: volume / area.
   - Average diameter: per PCI, the mean of the longest and perpendicular widths, or the equivalent-circle diameter.
5. Flag scans with water in the hole, since LiDAR returns from water are unreliable.

### Gaps
- None of the retrieved sources quantified how crown or cross-slope error propagates into volume error.
- No source gave an empirical optimal grid size or inlier tolerance for iPhone LiDAR.
- The Kamal water results were not broken out by water type in the retrieved abstract.

## Q3. Severity standards (ASTM D6433 PCI, FHWA DIM) and required accuracy

### Takeaway
PCI (ASTM D6433) grades potholes by maximum depth bands (13-25 mm, 25-50 mm, over 50 mm) crossed with average diameter bands (100-200, 200-450, 450-750 mm). Rutting is graded by average depth (6-13, 13-25, over 25 mm), and depressions by maximum depth (13-25, 25-50, over 50 mm). Crack width thresholds differ by manual:
- FHWA LTPP DIM asphalt: 6 mm and 19 mm.
- PCI/ASTM D6433: 10 mm and 75 mm.
- FHWA concrete: 3 mm and 6 mm (transverse).

Classifying severity reliably near the 13 and 25 mm boundaries needs depth error well under about 5 mm, which is at or beyond current iPhone LiDAR capability.

### Cited Findings
- **ASTM D6433-derived PCI training (TotalPave).**
  - Potholes are counted by L, M and H severity using a chart.
  - Rutting is measured in area, with severity by mean rut depth:
    - Low: 6-13 mm.
    - Medium: over 13 to 25 mm.
    - High: over 25 mm.
  - Depressions use maximum depth:
    - Low: 13-25 mm.
    - Medium: 25-50 mm.
    - High: over 50 mm.
  - Longitudinal and transverse cracks:
    - Low: unfilled width under 10 mm.
    - Medium: 10-75 mm.
    - High: over 75 mm.
  - Edge drop-off bands: 25-50, 50-100 and over 100 mm.
  - Extent should be measured "within 10% for linear" and "within 20% for area".
  - [TotalPave PCI Asphalt Distress Training](https://totalpave.com/wp-content/uploads/2021/11/PCI-Asphalt-Distress-Training.pdf)
- **FAA PAVEAIR pothole severity table (mirrors the ASTM PCI chart).**
  - Depth bands: 13 to 25 mm, over 25 to 50 mm, over 50 mm.
  - Average diameter columns: 100-200 mm, 200-450 mm, 450-750 mm.
  - Potholes over 750 mm in diameter: 25 mm deep or less is medium severity; deeper than 25 mm is high severity.
  - [FAA PAVEAIR potholes](https://faapaveair.faa.gov/Help/Documents/levelsofseverityforpotholes.htm); [FAA severity levels](https://faapaveair.faa.gov/Help/Documents/severitylevels43.htm)
  - The page could not be fetched directly (redirect loop). The table structure comes from a search snippet.
- **US depth-only classification cited in a Korean paper.** Low: under 25 mm. Moderate: 25 to under 50 mm. High: 50 mm or more. — [KoreaScience](https://koreascience.kr/article/CFKO202431947113015.pdf)
- **FHWA LTPP Distress Identification Manual (FHWA-HRT-13-092).**
  - Asphalt longitudinal and block cracking: low up to 6 mm mean width, moderate over 6 up to 19 mm, high over 19 mm.
  - Jointed concrete transverse cracking: low under 3 mm, moderate 3 to under 6 mm, high 6 mm or more.
  - Concrete longitudinal cracking: low under 3 mm, moderate 3 to under 13 mm, high 13 mm or more.
  - [FHWA DIM](https://www.fhwa.dot.gov/publications/research/infrastructure/pavements/ltpp/13092/13092.pdf); [JCP chapter](https://www.fhwa.dot.gov/publications/research/infrastructure/pavements/ltpp/13092/002.cfm)
- **Industry practice.** The Pavemetrics LCMS (Laser Crack Measurement System) product page lists pothole severity per ASTM/PCI. Not fetched. — [Pavemetrics potholes](https://www.pavemetrics.com/capabilities/lcms-2/potholes/)

### Inferences
- **Pothole cell mapping.** From the general knowledge of the ASTM D6433 chart (not verified from a fetched source in this session), the cells are believed to be:

  | Max depth | 100-200 mm | 200-450 mm | 450-750 mm |
  |---|---|---|---|
  | 13-25 mm | L | L | M |
  | 25-50 mm | L | M | H |
  | over 50 mm | M | M | H |

  Verify against ASTM D6433-24 or the FAA page before shipping.
- **Depth accuracy needed.** A ±10 mm depth error (the iPhone LiDAR order of magnitude) can move a pothole across the 25 mm or 13 mm boundaries.
  - The app should report "borderline" when the measured depth is within about 5-10 mm of a threshold.
  - Diameter accuracy of about 3-5% (Vogt x/y MAPE) is adequate for the 100/200/450/750 mm diameter bands.
  - The PCI extent tolerances (10% linear, 20% area) are easily met.
- **Crack-width severity.** iPhone LiDAR at a best case of about 1 cm resolution cannot classify FHWA asphalt crack severity (6 mm boundary) or concrete cracks (3 mm). It can at most flag PCI high-severity cracks over 75 mm wide.

### Gaps
- The exact ASTM D6433 pothole matrix and the minimum-size rule (100 mm diameter) could not be read from a primary source (the standard is paywalled; the FAA page did not load).
- The FHWA DIM asphalt pothole definition was not retrieved. The DIM records potholes by count and area, with severity by depth (under 25, 25-50, over 50 mm), but this is unconfirmed here.

## Q4. Crack detection and width measurement: LiDAR alone vs images

### Takeaway
Phone LiDAR alone cannot measure pavement crack width at severity-relevant scales: the best-case resolution is about 1 cm, and small cracks were not detected. Cracks should be detected and measured from the RGB images, with LiDAR depth used for scale. Sub-millimetre crack width has been reported only with mobile LiDAR plus spatial reference targets, or with LiDAR-RGB fusion at close range.

### Cited Findings
- iPad and iPhone LiDAR "could not detect smaller cracks." 2D detail with photo overlay is comparable to conventional cameras, and colorised scans helped identify damage on moderately damaged concrete. — [ROSA P MTI](https://rosap.ntl.bts.gov/view/dot/75721); [MTI brief](https://transweb.sjsu.edu/sites/default/files/2224-RB-Peterson-LiDAR-Surface-Texture-Assessment.pdf)
- **Mobile LiDAR crack width on reinforced concrete.**
  - With spatial measurement targets (SMTs): average deviations around ±0.50 mm.
  - Without targets: errors over 1.5 mm.
  - The device and app are unclear from the snippet.
  - [Erciyes Univ. AVESIS](https://avesis.erciyes.edu.tr/publication/details/f02a9c53-16cf-4f97-8c6c-fcaa8f8e6632/oai)
- **LiDAR-RGB fusion (2025).** A visual-inertial LiDAR fusion paper with Segment Anything refinement measures concrete cracks in 3D. It notes that crack width accuracy "is inherently constrained by the acquisition distance." — [arXiv 2501.09203](https://arxiv.org/pdf/2501.09203)
- **Smartphone LiDAR vs TLS crack detection (2024, IEEE conference, UiTM).** Only an abstract was found; no numbers. — [UiTM record](https://update.library.uitm.edu.my/Record/2-s2.0-85203788019/Details)

### Inferences
- **Practical design.**
  - Run 2D crack segmentation on the ARKit captured RGB frames.
  - Convert pixel width to mm using the per-pixel LiDAR depth and the camera intrinsics.
  - At 0.3-0.5 m capture distance, a 1920 px wide image covers about 0.4-0.6 m, which is about 0.2-0.3 mm per pixel. This is adequate for the 3/6/10/19 mm thresholds.
  - This is an inference and has not been validated in a cited study.

### Gaps
- No study was found that reports iPhone image plus LiDAR-scaled crack width error on asphalt against crack comparator gauges.

## Q5. Recommended scanning distance and procedure

### Takeaway
Keep scans short and local, with one pothole per scan, close range (under about 1-2 m, well within the 5 m sensor range), slow and steady movement, and dry surfaces. Large-area or long-duration scans accumulate IMU drift and misalignment.

### Cited Findings
- "Longer scans (in terms of both time and distance) led to geometric anomalies." Scans over larger areas exhibited misalignments. The recommendations were gimbal stabilisers and raw-data processing instead of opaque app processing. — [ROSA P](https://rosap.ntl.bts.gov/view/dot/75721); [MTI brief](https://transweb.sjsu.edu/sites/default/files/2224-RB-Peterson-LiDAR-Surface-Texture-Assessment.pdf)
- Vogt et al. scanned at "low walking speeds" with the handheld device. — [TUM](https://portal.fis.tum.de/en/publications/a-mobile-mapping-solution-for-vru-infrastructure-monitoring-via-l/)
- The iPhone LiDAR effective range is under 5 m. Dataset spec: up to 5 m range, ±1-2% ranging accuracy. — [PLOS ONE](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0344604); [IEEE DataPort](https://ieee-dataport.org/node/15492)
- Accuracy degrades from ±1 cm on objects over 10 cm in size to ±10 cm on 130 m scenes. — [Luetzenburg 2021](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8593014/)
- Avoid wet, glossy and dark surfaces, and intense sun, fog or rain. — [PLOS ONE](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0344604)
- For vehicle-mounted depth cameras, re-estimate the sensor height per frame from the median depth of the intact surface. — [arXiv 2505.04207](https://arxiv.org/pdf/2505.04207v1)

### Inferences
Suggested iOS procedure:
1. Hold the phone about 0.5-1.0 m above the surface, roughly nadir (pointing straight down).
2. Make a slow sweep (under 10-20 s) covering the hole plus a 0.3-0.5 m intact margin all around.
3. Optionally place a scale target or known-size object for validation.
4. Capture on dry pavement.
5. Fuse multiple depth frames to reduce noise, rather than relying on one frame.

### Gaps
- No study was found that reported error as a function of iPhone height or distance for potholes, so the 0.5-1.0 m figure is inferred from general sensor behaviour.
