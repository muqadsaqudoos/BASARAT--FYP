# ML Kit text recognition: optional language modules (Chinese, Devanagari, Japanese, Korean)
# are not included by default. Suppress R8 errors for these missing classes.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
