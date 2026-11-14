# Localization and accessibility

Localizable.xcstrings contains explicit keys for English, Sinhala, Tamil, Hindi, Arabic, French and Simplified Chinese. Sinhala is the default. Settings changes the resource bundle, Locale and Arabic layout direction without an account or relaunch. The source catalog is generated from scripts/localizations.py and translation_supplements.py; all non-English values are drafts marked needs_review. They must be reviewed by fluent technical speakers before release.

Run scripts/check_localization.py to check coverage, empty values, and dynamic key families. English is the fallback for unexpected/missing translations. Paths, application names and OS-provided errors remain exact or use the operating system’s language; they must not be fabricated or translated as filenames.

The app uses native Buttons, Lists, Table, Toggles, Pickers and confirmation controls with text. Risk is expressed in words and symbols. The interactive treemap has a text alternative. File selection toggles include the filename in their accessibility label. Cmd-O chooses a folder; Cmd-. cancels scanning; native controls support standard keyboard focus and arrows. No animation depends on motion, and standard semantic colors follow system light/dark/high-contrast appearances.

Manual release checks remain necessary: VoiceOver traversal and focus after navigation, keyboard-only scanning and review cancellation, long Sinhala/Tamil/French strings at minimum window size, Arabic RTL, increased text sizes, Increase Contrast and Reduce Motion. Font sizes are native semantic styles; macOS does not offer the same global Dynamic Type controls as iOS.
