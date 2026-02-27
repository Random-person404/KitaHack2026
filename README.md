# KitaHack2026

Technical Architecture
- Modular Frontend: Flutter cross-platform UI for high-frame-rate rendering and real-time landmark overlays.
- Decoupled Backend: Google Cloud Run (Serverless) manages heavy AI inference, offloading tasks to preserve mobile battery life.
- The "Brain": Gemini 2.5 Flash (via Vertex AI) providing Multimodal Live reasoning and 1M token context for spatial memory.
- Edge-Cloud Hybrid: MediaPipe on-device for hand/face landmarks; only lightweight data is sent to the cloud to reduce bandwidth.
- Data & Security: Firebase (Auth, Firestore, Analytics) for secure user management and real-time data syncing.
- Global Latency: Regional endpoints (e.g., asia-southeast1) ensuring sub-300ms response times.

Implementation Details
- Solution Flow: Real-time "Stream-and-Reason" logic using WebSockets for a continuous data bridge.
- Linguistic Fusion: Gemini 2.5 processes hand signs simultaneously with facial expressions (Non-Manual Markers).
- Grammatical Refinement: SignGemma (Gemma 2) transforms ASL/BIM Topic-Comment structures into polished English.
- Continuous Recognition: Move from "static" template matching to Temporal Video Reasoning (detecting motion paths).
- Spatial Awareness: Using Gemini’s context window to remember 3D "placements" of people/objects in the signing space.
- Performance Tracking: BigQuery integration to monitor "Task Success Rates" and 3.4x medical error reduction goals.

Challenges Faced
- The Problem: Distinguishing dynamic letters (J, Z) which require tracking motion over time ($t$) rather than just static coordinates.
- Technical Hurdles: Sequence variability (user speed), motion blurring on standard webcams, and data dimensionality.
- Failed Approaches: "Snapshot" methods and hardcoded "If-Else" heuristics were too rigid for real-world use.
- The Solution: Implemented GRU (Gated Recurrent Units) for temporal feature extraction.
- Buffer System: Created a Sliding Window (30 frames) to analyze the "shape" of movement regardless of speed.
- Result: Accuracy for dynamic signs jumped from 0% to >85%, providing the architectural bridge for full-sentence recognition.

Future Roadmap
- Phase 1: Deep Temporal Specialization (0–6 Months)
  Action: Expand the GRU/LSTM Buffer from letters ('J', 'Z') to Medical Action Verbs (e.g., "throbbing," "bleeding," "swelling").
  Goal: Launch the "Medical First" Initiative at GH Penang, ensuring the system can detect the speed and intensity of signs to communicate pain levels accurately.
- Phase 2: Full-Sentence Linguistic Fusion (6–12 Months)
  Action: Transition from "Sliding Windows" to Gemini 2.0’s 1M Token Context, allowing the system to remember signs made minutes ago.
  Goal: Launch "Accessibility-as-a-Service" (AaaS) for banks (Maybank/CIMB). The system will handle complex, multi-sign sentences like "I lost my credit card yesterday" by linking temporal motion with spatial memory.
- Phase 3: Wearable Motion-Tracking (12+ Months)
  Action: Port the MediaPipe/TFLite edge-engine to AR Glasses to handle motion tracking from a first-person perspective.
  Goal: "The Subtitle Era." Real-time subtitles projected onto AR lenses. Because the system already mastered "Dynamic Motion" in the prototype, it can now provide 99% accurate, hands-free translation in live public settings like KLIA or LRT stations.
