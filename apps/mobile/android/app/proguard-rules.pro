# ONNX Runtime's Java API is looked up from JNI by class and method name.
# R8 must not rename or strip it, otherwise OrtSession.run aborts the process
# with "JNI DETECTED ERROR ... java_class == null" in release builds.
-keep class ai.onnxruntime.** { *; }
-keepclassmembers class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# The Flutter plugin that drives ONNX Runtime uses reflection-like JNI entry points.
-keep class com.masicai.flutteronnxruntime.** { *; }
