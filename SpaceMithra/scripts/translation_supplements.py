"""Draft translations. Kept separate for human review and replacement."""
TRANSLATIONS = {}
def add(locale, text):
    TRANSLATIONS[locale] = dict(line.split('|',1) for line in text.strip().splitlines())
add('si', '''
locations|ස්ථාන
allAccessible|ප්‍රවේශ විය හැකි ගබඩාවක් තෝරන්න…
volumes|සම්බන්ධිත ධාවක
applications|යෙදුම්
documents|ලේඛන
downloads|බාගැනීම්
desktop|ඩෙස්ක්ටොප්
pictures|පින්තූර
movies|වීඩියෝ
music|සංගීතය
library|පුස්තකාලය
scan|පරිලෝකනය
pause|විරාමය
resume|නැවත අරඹන්න
items|අයිතම
scanErrors|කියවිය නොහැකි හෝ වෙනස් වූ
seconds|තත්පර
welcomeSubtitle|ඔබේ ගබඩාව තේරුම් ගන්න. තබාගන්නා දේ තෝරන්න.
privacy|නොබැඳි සහ පෞද්ගලිකයි. ගිණුම්, උඩුගත කිරීම්, දැන්වීම් හෝ භාවිත දත්ත රැස් කිරීම නැත.
scanGuidance|පරිලෝකනයට ෆෝල්ඩරයක් තෝරන්න. මෙය පාරදත්ත පමණක් කියවයි. macOS අවසර ඉල්ලා සිටිය හැක. ප්‍රවේශය ප්‍රතික්ෂේප වුවහොත් වෙනත් ෆෝල්ඩරයක් තෝරන්න. සම්පූර්ණ තැටි ප්‍රවේශය ආරම්භයේදී ඉල්ලන්නේ නැත.
diskUsage|ධාවක භාවිතය
distribution|ෆෝල්ඩර බෙදාහැරීම
partialNotice|වත්මන් පිටුවේ විශාලතම අයිතම 12ක් දක්වයි. අසම්පූර්ණ පරිලෝකන සහ ප්‍රවේශ නොහැකි ගොනු නිසා එකතුව අසම්පූර්ණ විය හැක. APFS ගොනු තැටි කොටස් බෙදාගත හැක.
trends|පරිලෝකන ඉතිහාසය
trendNotice|එකතු පරිලෝකනය කළ තාර්කික බයිට් වේ. වෙනස් ෆෝල්ඩර සහ ප්‍රවේශ සීමා නිසා පරිලෝකන සැසඳිය නොහැකි විය හැක.
date|දිනය
type|වර්ගය
risk|අවදානම
parentFolder|මව් ෆෝල්ඩරය
search|පරිලෝකනය කළ නම් සොයන්න
sort|අනුපිළිවෙල
category|ප්‍රවර්ගය
all|සියලු ප්‍රවර්ග
minimumMB|අවම MB
extension|ගොනු දිගුව
modifiedAfter|මෙම දිනට පසු වෙනස් කළ
apply|යොදන්න
scanInProgress|පරිලෝකනය සිදුවෙමින් පවතී. ප්‍රතිඵල අසම්පූර්ණයි. පිරිසිදු කිරීම අක්‍රියයි.
previous|පෙර
next|ඊළඟ
selectEligible|පිටුවේ සුදුසු අයිතම තෝරන්න
deselectPage|පිටුවේ තේරීම් ඉවත් කරන්න
reveal|Finder තුළ පෙන්වන්න
reviewTrash|තෝරාගත් ගොනු සමාලෝචනය කරන්න…
confirmTitle|මෙම නිශ්චිත ගොනු කුණු කූඩයට ගෙන යන්නද?
reviewConsequences|සෑම මාර්ගයක් සහ ප්‍රතිවිපාකයක්ම සමාලෝචනය කරන්න. වෙනස් වූ, ආරක්ෂිත හෝ ප්‍රවේශ නොහැකි අයිතම මඟහරියි. නොදන්නා ගොනුවල වැදගත් දත්ත තිබිය හැක.
moveToTrash|තෝරාගත් ගොනු කුණු කූඩයට ගෙන යන්න
deselectAll|සියලු තේරීම් ඉවත් කරන්න
permanent|ඉවත් කරන තුරු
oneDay|පැය 24ක් ආරක්ෂා කරන්න
removeProtection|රීතිය ඉවත් කරන්න
restoreWarning|පවතින ගොනු උඩින් නොලියා මුල් ස්ථානයට ප්‍රතිසාධනය කරන්න. කුණු කූඩය හිස් කර ඇත්නම් ප්‍රතිසාධනය කළ නොහැක.
duplicateGuidance|SHA-256 සමාන අනුපිටපත්. පිටපත් වෙන වෙනම තෝරා අවම වශයෙන් එකක් තබාගන්න. දෘඪ සබැඳි සහ වලාකුළු ගොනු බැහැර කරයි. APFS හවුල් කොටස් හඳුනාගත නොහැක.
findDuplicates|නිශ්චිත අනුපිටපත් සොයන්න
showHidden|සැඟවුණු ගොනු පෙන්වන්න
translationNotice|පරිවර්තන කෙටුම්පත් වන අතර චතුර කථිකයන්ගේ සමාලෝචනය අවශ්‍යයි.
limitations|ෆෝල්ඩර පිරිසිදු කිරීම, මෙවලම් විධාන, සජීවී භාවිත හඳුනාගැනීම සහ ස්වයංක්‍රීය පද්ධති පිරිසිදු කිරීම නොමැත. නොදන්නා දත්ත ස්වයංක්‍රීයව තෝරන්නේ නැත.
error|ක්‍රියාව සම්පූර්ණ කළ නොහැක
ok|හරි
allocated|වෙන් කළ ඉඩ ඇස්තමේන්තුව
created|නිර්මාණය කළ
modified|වෙනස් කළ
opened|අවසන් ප්‍රවේශය (විවෘත කළ දිනයම නොවේ)
owner|හඳුනාගත් හැඹිලි හිමිකරු
activeUse|දැනට භාවිතය
unavailable|නොමැත / තහවුරු කර නැත
recoveryNotice|ප්‍රතිසාධනය කොන්දේසි සහිතයි. කුණු කූඩය හිස් කළ පසු ප්‍රතිසාධනය නැත.
preview|ඉක්මන් පෙරදසුන
riskLevel.low|අඩු
risk.protected|පද්ධති සීමාවක් හෝ ආරක්ෂණ රීතියක් පිරිසිදු කිරීම වළක්වයි.
consequence.protected|මෙම අයිතමය එලෙසම තබන්න.
risk.special|මෙය ෆෝල්ඩරයක්, සබැඳියක්, පැකේජ අයිතමයක්, දෘඪ සබැඳියක් හෝ වලාකුළු අයිතමයකි.
consequence.special|ඉවත් කිරීම වෙනත් ස්ථාන, යෙදුම් හෝ සමමුහුර්ත උපාංගවලට බලපෑ හැක. පිරිසිදු කිරීම අවහිරයි.
risk.database|මෙහි යෙදුම් තත්ත්වය හෝ දත්ත සමුදායක් තිබිය හැක.
consequence.database|මකා දැමීමෙන් යෙදුම් දත්ත නැතිවිය හැක. පිරිසිදු කිරීම අවහිරයි.
risk.cache|හඳුනාගත් හැඹිලි මාර්ගයක නැවත සෑදිය හැකි දත්ත තිබිය හැක. වත්මන් භාවිතය සහ පරායත්තතා තහවුරු කර නැත.
consequence.cache|හිමිකරු යෙදුම වසන්න. මකා දැමීමෙන් මුල් පැටවීම මන්දගාමී විය හැකි අතර පෙරදසුන්, ගොඩනැගීම් හෝ බාගැනීම් නැවත අවශ්‍ය විය හැක.
risk.recent|මෙම ගොනුව මෑතකදී වෙනස් කර ඇත, නැතහොත් වෙනස් කළ දිනය නොමැත.
consequence.user|මකා දැමීමෙන් පෞද්ගලික හෝ ව්‍යාපෘති දත්ත නැතිවිය හැක. මෙම නිශ්චිත ගොනුව තවදුරටත් අවශ්‍ය නැති බව තහවුරු කරන්න.
risk.unknown|මෙම අයිතමයේ අරමුණ තහවුරු කරන පිරිසිදු කිරීමේ රීතියක් නැත.
history.pending|අපේක්ෂිත / අවිනිශ්චිත — කුණු කූඩය පරීක්ෂා කරන්න
history.trashed|කුණු කූඩයට ගෙන ගියේය
history.skipped|මඟහැරිය / අසාර්ථකයි — විස්තර බලන්න
history.uncertain|ප්‍රතිඵලය අවිනිශ්චිතයි — කුණු කූඩය පරීක්ෂා කරන්න
history.restoring|ප්‍රතිසාධනය අවිනිශ්චිතයි — මුල් මාර්ගය පරීක්ෂා කරන්න
history.restored|ප්‍රතිසාධනය කළා
state.idle|නිෂ්ක්‍රීයයි
state.preparing|සූදානම් වෙමින්
state.scanning|පරිලෝකනය කරමින්
state.paused|විරාමයේ
state.completed|සම්පූර්ණයි
state.cancelled|අවලංගුයි
state.failed|අසාර්ථකයි
category.applications|යෙදුම්
category.documents|ලේඛන
category.images|පින්තූර
category.videos|වීඩියෝ
category.audio|ශ්‍රව්‍ය
category.archives|සංරක්ෂිත ගොනු
category.installers|බාගත් ස්ථාපක
category.caches|තාවකාලික හැඹිලි
category.logs|ලොග්
category.backups|උපස්ථ
category.developer|සංවර්ධක ගොනු
category.support|යෙදුම් සහාය දත්ත
category.cloud|වලාකුළු කළමනාකරණ ගොනු
category.unknown|නොදන්නා දත්ත
''')
add('ta', '''
locations|இடங்கள்
allAccessible|அணுகக்கூடிய சேமிப்பகத்தைத் தேர்ந்தெடு…
volumes|இணைக்கப்பட்ட வட்டுகள்
applications|செயலிகள்
documents|ஆவணங்கள்
downloads|பதிவிறக்கங்கள்
desktop|மேசைப்பலகை
pictures|படங்கள்
movies|காணொளிகள்
music|இசை
library|நூலகம்
scan|வருடு
pause|இடைநிறுத்து
resume|தொடரவும்
items|உருப்படிகள்
scanErrors|படிக்க முடியாதவை அல்லது மாற்றப்பட்டவை
seconds|விநாடிகள்
welcomeSubtitle|சேமிப்பகத்தைப் புரிந்துகொள்ளுங்கள். எதை வைத்திருக்க வேண்டும் என்பதைத் தேர்ந்தெடுங்கள்.
privacy|இணையமின்றி தனியுரிமையுடன். கணக்குகள், பதிவேற்றங்கள், விளம்பரங்கள் அல்லது பயன்பாட்டுத் தரவு சேகரிப்பு இல்லை.
scanGuidance|வருட ஒரு கோப்புறையைத் தேர்ந்தெடுக்கவும். வருடல் மெட்டாடேட்டாவை மட்டுமே படிக்கும். macOS அனுமதி கேட்கலாம். அணுகல் மறுக்கப்பட்டால் மற்றொரு கோப்புறையைத் தேர்ந்தெடுக்கவும். தொடக்கத்தில் முழு வட்டு அணுகல் கேட்கப்படாது.
diskUsage|வட்டுப் பயன்பாடு
distribution|கோப்புறைப் பகிர்வு
partialNotice|தற்போதைய பக்கத்தில் மிகப்பெரிய 12 உருப்படிகள் காட்டப்படும். முழுமையற்ற வருடலும் அணுக முடியாத கோப்புகளும் மொத்தத்தைப் பாதிக்கும். APFS நகல்கள் தொகுதிகளைப் பகிரலாம்.
trends|வருடல் வரலாறு
trendNotice|மொத்தங்கள் வருடப்பட்ட தருக்க பைட்டுகள். வெவ்வேறு இடங்கள் மற்றும் அணுகல் வரம்புகளால் வருடல்களை ஒப்பிட முடியாமல் போகலாம்.
date|தேதி
type|வகை
risk|அபாயம்
parentFolder|பெற்றோர் கோப்புறை
search|வருடப்பட்ட பெயர்களைத் தேடு
sort|வரிசைப்படுத்து
category|பிரிவு
all|அனைத்துப் பிரிவுகள்
minimumMB|குறைந்தபட்ச MB
extension|கோப்பு நீட்சி
modifiedAfter|இதற்குப் பிறகு மாற்றப்பட்டது
apply|பயன்படுத்து
scanInProgress|வருடல் நடைபெறுகிறது. முடிவுகள் முழுமையற்றவை; சுத்தப்படுத்த முடியாது.
previous|முந்தைய
next|அடுத்த
selectEligible|பக்கத்தில் தகுதியானவற்றைத் தேர்ந்தெடு
deselectPage|பக்கத் தேர்வை நீக்கு
reveal|Finder இல் காட்டு
reviewTrash|தேர்ந்தெடுத்த கோப்புகளைச் சரிபார்…
confirmTitle|இந்தக் குறிப்பிட்ட கோப்புகளைக் குப்பைக்கு நகர்த்தவா?
reviewConsequences|ஒவ்வொரு பாதையையும் விளைவையும் சரிபார்க்கவும். மாற்றப்பட்ட, பாதுகாக்கப்பட்ட அல்லது அணுக முடியாத உருப்படிகள் தவிர்க்கப்படும். தெரியாத கோப்புகளில் முக்கியமான தரவு இருக்கலாம்.
moveToTrash|தேர்ந்தெடுத்த கோப்புகளைக் குப்பைக்கு நகர்த்து
deselectAll|அனைத்துத் தேர்வுகளையும் நீக்கு
permanent|நீக்கும் வரை
oneDay|24 மணிநேரம் பாதுகாக்கவும்
removeProtection|விதியை நீக்கு
restoreWarning|இருக்கும் கோப்புகளை மேலெழுதாமல் அசல் இடத்திற்கு மீட்டமைக்கவும். குப்பை காலியாக்கப்பட்டிருந்தால் மீட்பு கிடைக்காது.
duplicateGuidance|SHA-256 மூலம் துல்லியமான நகல்கள். தனித்தனியாகத் தேர்ந்தெடுத்து குறைந்தது ஒரு நகலை வைத்திருங்கள். கடின இணைப்புகள் மற்றும் மேகக் கோப்புகள் விலக்கப்படும். APFS பகிரப்பட்ட தொகுதிகளை அடையாளம் காண முடியாது.
findDuplicates|துல்லியமான நகல்களைக் கண்டறி
showHidden|மறைக்கப்பட்ட கோப்புகளைக் காட்டு
translationNotice|மொழிபெயர்ப்புகள் வரைவுகள்; சரளமாகப் பேசுவோர் மதிப்பாய்வு செய்ய வேண்டும்.
limitations|கோப்புறை சுத்தப்படுத்தல், கருவிக் கட்டளைகள், நேரடி பயன்பாடு கண்டறிதல் மற்றும் தானியங்கு அமைப்புச் சுத்தப்படுத்தல் இல்லை. தெரியாத தரவு தானாகத் தேர்ந்தெடுக்கப்படாது.
error|செயலை முடிக்க முடியவில்லை
ok|சரி
allocated|ஒதுக்கப்பட்ட அளவின் மதிப்பீடு
created|உருவாக்கப்பட்டது
modified|மாற்றப்பட்டது
opened|கடைசியாக அணுகியது (திறந்த நேரமாக இருக்க வேண்டியதில்லை)
owner|அறியப்பட்ட தற்காலிகச் சேமிப்பு உரிமையாளர்
activeUse|தற்போதைய பயன்பாடு
unavailable|கிடைக்கவில்லை / உறுதிப்படுத்தப்படவில்லை
recoveryNotice|மீட்பு நிபந்தனைக்குட்பட்டது. குப்பை காலியான பிறகு மீட்க முடியாது.
preview|விரைவுப் பார்வை
riskLevel.low|குறைவு
risk.protected|அமைப்புக் கட்டுப்பாடு அல்லது பாதுகாப்பு விதி சுத்தப்படுத்தலைத் தடுக்கிறது.
consequence.protected|இந்த உருப்படியை அப்படியே வைத்திருக்கவும்.
risk.special|இது கோப்புறை, இணைப்பு, தொகுப்பு உருப்படி, கடின இணைப்பு அல்லது மேக உருப்படி.
consequence.special|நீக்குதல் பிற இடங்கள், செயலிகள் அல்லது ஒத்திசைக்கப்பட்ட சாதனங்களைப் பாதிக்கலாம். சுத்தப்படுத்தல் தடுக்கப்பட்டது.
risk.database|இதில் செயலி நிலை அல்லது தரவுத்தளம் இருக்கலாம்.
consequence.database|நீக்கினால் செயலித் தரவை இழக்கலாம். சுத்தப்படுத்தல் தடுக்கப்பட்டது.
risk.cache|அறியப்பட்ட தற்காலிகச் சேமிப்புப் பாதையில் மீண்டும் உருவாகும் தரவு இருக்கலாம். பயன்பாடு மற்றும் சார்புகள் உறுதிப்படுத்தப்படவில்லை.
consequence.cache|தொடர்புடைய செயலியை மூடவும். நீக்கினால் ஏற்றுதல் மெதுவாகலாம்; முன்னோட்டங்கள், கட்டமைப்புகள் அல்லது பதிவிறக்கங்களை மீண்டும் உருவாக்க வேண்டியிருக்கலாம்.
risk.recent|இந்தக் கோப்பு சமீபத்தில் மாற்றப்பட்டது அல்லது மாற்றிய தேதி கிடைக்கவில்லை.
consequence.user|நீக்கினால் தனிப்பட்ட அல்லது திட்டத் தரவை இழக்கலாம். இந்தக் கோப்பு தேவையில்லை என்பதை உறுதிசெய்யவும்.
risk.unknown|இந்த உருப்படியின் நோக்கத்தை உறுதிப்படுத்தும் சுத்தப்படுத்தல் விதி இல்லை.
history.pending|நிலுவை / உறுதியில்லை — குப்பையைச் சரிபார்க்கவும்
history.trashed|குப்பைக்கு நகர்த்தப்பட்டது
history.skipped|தவிர்க்கப்பட்டது / தோல்வி — விவரங்களைப் பார்க்கவும்
history.uncertain|முடிவு உறுதியில்லை — குப்பையைச் சரிபார்க்கவும்
history.restoring|மீட்பு உறுதியில்லை — அசல் பாதையைச் சரிபார்க்கவும்
history.restored|மீட்டமைக்கப்பட்டது
state.idle|செயலற்றது
state.preparing|தயாராகிறது
state.scanning|வருடுகிறது
state.paused|இடைநிறுத்தப்பட்டது
state.completed|முடிந்தது
state.cancelled|ரத்துசெய்யப்பட்டது
state.failed|தோல்வி
category.applications|செயலிகள்
category.documents|ஆவணங்கள்
category.images|படங்கள்
category.videos|காணொளிகள்
category.audio|ஒலி
category.archives|காப்பகங்கள்
category.installers|பதிவிறக்கிய நிறுவிகள்
category.caches|தற்காலிகச் சேமிப்புகள்
category.logs|பதிவுகள்
category.backups|காப்புப்பிரதிகள்
category.developer|மேம்பாட்டுக் கோப்புகள்
category.support|செயலி ஆதரவுத் தரவு
category.cloud|மேக நிர்வகிப்புக் கோப்புகள்
category.unknown|தெரியாத தரவு
''')
add('hi', '''
locations|स्थान
allAccessible|सुलभ स्टोरेज चुनें…
volumes|जुड़ी हुई ड्राइव
applications|ऐप्स
documents|दस्तावेज़
downloads|डाउनलोड
desktop|डेस्कटॉप
pictures|चित्र
movies|वीडियो
music|संगीत
library|लाइब्रेरी
scan|स्कैन
pause|रोकें
resume|जारी रखें
items|आइटम
scanErrors|अपठनीय या बदले हुए
seconds|सेकंड
welcomeSubtitle|अपना स्टोरेज समझें। तय करें कि क्या रखना है।
privacy|ऑफ़लाइन और निजी। कोई खाता, अपलोड, विज्ञापन या उपयोग डेटा संग्रह नहीं।
scanGuidance|स्कैन करने के लिए फ़ोल्डर चुनें। स्कैन केवल मेटाडेटा पढ़ता है। macOS अनुमति माँग सकता है। अनुमति न मिलने पर दूसरा फ़ोल्डर चुनें। शुरुआत में पूर्ण डिस्क पहुँच नहीं माँगी जाती।
diskUsage|ड्राइव उपयोग
distribution|फ़ोल्डर वितरण
partialNotice|वर्तमान पृष्ठ के अधिकतम 12 सबसे बड़े आइटम दिखते हैं। अधूरे स्कैन और अप्राप्य फ़ाइलों से कुल अधूरा हो सकता है। APFS क्लोन ब्लॉक साझा कर सकते हैं।
trends|स्कैन इतिहास
trendNotice|कुल स्कैन किए गए तार्किक बाइट हैं। अलग फ़ोल्डर और पहुँच सीमाओं के कारण स्कैन अतुलनीय हो सकते हैं।
date|तारीख़
type|प्रकार
risk|जोखिम
parentFolder|ऊपरी फ़ोल्डर
search|स्कैन किए गए नाम खोजें
sort|क्रम
category|श्रेणी
all|सभी श्रेणियाँ
minimumMB|न्यूनतम MB
extension|एक्सटेंशन
modifiedAfter|इसके बाद संशोधित
apply|लागू करें
scanInProgress|स्कैन जारी है। परिणाम अधूरे हैं; सफ़ाई अनुपलब्ध है।
previous|पिछला
next|अगला
selectEligible|पृष्ठ के योग्य आइटम चुनें
deselectPage|पृष्ठ का चयन हटाएँ
reveal|Finder में दिखाएँ
reviewTrash|चुनी हुई फ़ाइलें जाँचें…
confirmTitle|इन सटीक फ़ाइलों को ट्रैश में भेजें?
reviewConsequences|हर पथ और परिणाम जाँचें। बदले हुए, सुरक्षित या अप्राप्य आइटम छोड़ दिए जाएँगे। अज्ञात फ़ाइलों में महत्वपूर्ण डेटा हो सकता है।
moveToTrash|चुनी हुई फ़ाइलें ट्रैश में भेजें
deselectAll|सभी चयन हटाएँ
permanent|हटाने तक
oneDay|24 घंटे सुरक्षित रखें
removeProtection|नियम हटाएँ
restoreWarning|मौजूदा फ़ाइलों पर लिखे बिना मूल स्थान पर पुनर्स्थापित करें। ट्रैश खाली हो चुका है तो पुनर्प्राप्ति उपलब्ध नहीं है।
duplicateGuidance|सटीक SHA-256 डुप्लिकेट। प्रतियाँ अलग-अलग चुनें और कम से कम एक रखें। हार्ड लिंक और क्लाउड फ़ाइलें शामिल नहीं हैं। APFS साझा ब्लॉक पहचाने नहीं जा सकते।
findDuplicates|सटीक डुप्लिकेट खोजें
showHidden|छिपी फ़ाइलें दिखाएँ
translationNotice|अनुवाद प्रारूप हैं; धाराप्रवाह वक्ताओं की समीक्षा आवश्यक है।
limitations|फ़ोल्डर सफ़ाई, टूल कमांड, सक्रिय उपयोग का पता लगाना और स्वचालित सिस्टम सफ़ाई उपलब्ध नहीं हैं। अज्ञात डेटा कभी अपने आप नहीं चुना जाता।
error|कार्रवाई पूरी नहीं हो सकी
ok|ठीक है
allocated|आवंटित स्थान का अनुमान
created|बनाया गया
modified|संशोधित
opened|अंतिम पहुँच (ज़रूरी नहीं कि खोला गया हो)
owner|पहचाना गया कैश स्वामी
activeUse|सक्रिय उपयोग
unavailable|अनुपलब्ध / प्रमाणित नहीं
recoveryNotice|पुनर्प्राप्ति सशर्त है। ट्रैश खाली होने के बाद पुनर्प्राप्ति नहीं।
preview|त्वरित पूर्वावलोकन
riskLevel.low|कम
risk.protected|सिस्टम प्रतिबंध या सुरक्षा नियम सफ़ाई रोकता है।
consequence.protected|इस आइटम को यहीं रहने दें।
risk.special|यह फ़ोल्डर, लिंक, पैकेज आइटम, हार्ड लिंक या क्लाउड आइटम है।
consequence.special|हटाने से अन्य स्थान, ऐप्स या सिंक किए गए डिवाइस प्रभावित हो सकते हैं। सफ़ाई अवरुद्ध है।
risk.database|इसमें ऐप की स्थिति या डेटाबेस हो सकता है।
consequence.database|हटाने से ऐप डेटा खो सकता है। सफ़ाई अवरुद्ध है।
risk.cache|पहचाने गए कैश पथ में दोबारा बनने वाला डेटा हो सकता है। सक्रिय उपयोग और निर्भरताएँ प्रमाणित नहीं हैं।
consequence.cache|संबंधित ऐप बंद करें। हटाने से आरंभिक लोड धीमा हो सकता है या पूर्वावलोकन, बिल्ड या डाउनलोड दोबारा बनाने पड़ सकते हैं।
risk.recent|यह फ़ाइल हाल ही में बदली गई है या संशोधन तारीख़ उपलब्ध नहीं है।
consequence.user|हटाने से निजी या परियोजना डेटा खो सकता है। पुष्टि करें कि इस सटीक फ़ाइल की आवश्यकता नहीं है।
risk.unknown|इस आइटम का उद्देश्य स्थापित करने वाला कोई सफ़ाई नियम नहीं है।
history.pending|लंबित / अनिश्चित — ट्रैश जाँचें
history.trashed|ट्रैश में भेजा गया
history.skipped|छोड़ा गया / विफल — विवरण देखें
history.uncertain|परिणाम अनिश्चित — ट्रैश जाँचें
history.restoring|पुनर्स्थापना अनिश्चित — मूल पथ जाँचें
history.restored|पुनर्स्थापित
state.idle|निष्क्रिय
state.preparing|तैयारी
state.scanning|स्कैन जारी
state.paused|रुका हुआ
state.completed|पूरा
state.cancelled|रद्द
state.failed|विफल
category.applications|ऐप्स
category.documents|दस्तावेज़
category.images|चित्र
category.videos|वीडियो
category.audio|ऑडियो
category.archives|संग्रह
category.installers|डाउनलोड किए इंस्टॉलर
category.caches|अस्थायी कैश
category.logs|लॉग
category.backups|बैकअप
category.developer|डेवलपर फ़ाइलें
category.support|ऐप सहायता डेटा
category.cloud|क्लाउड प्रबंधित फ़ाइलें
category.unknown|अज्ञात डेटा
''')
add('ar', '''
locations|المواقع
allAccessible|اختيار مساحة تخزين متاحة…
volumes|وحدات التخزين المتصلة
applications|التطبيقات
documents|المستندات
downloads|التنزيلات
desktop|سطح المكتب
pictures|الصور
movies|الفيديو
music|الموسيقى
library|المكتبة
scan|فحص
pause|إيقاف مؤقت
resume|متابعة
items|عناصر
scanErrors|غير مقروءة أو متغيرة
seconds|ثوانٍ
welcomeSubtitle|افهم مساحة التخزين واختر ما تريد الاحتفاظ به.
privacy|خاص ويعمل دون اتصال. بلا حسابات أو رفع ملفات أو إعلانات أو جمع بيانات استخدام.
scanGuidance|اختر مجلداً لفحصه. يقرأ الفحص البيانات الوصفية فقط. قد يطلب macOS إذناً. إذا رُفض الوصول فاختر مجلداً آخر. لا يُطلب الوصول الكامل للقرص عند بدء التشغيل.
diskUsage|استخدام وحدة التخزين
distribution|توزيع المجلدات
partialNotice|تعرض الصفحة الحالية حتى 12 من أكبر العناصر. الفحص الجزئي والملفات غير المتاحة يجعلان الإجماليات ناقصة. قد تتشارك نسخ APFS كتل التخزين.
trends|سجل الفحص
trendNotice|الإجماليات هي بايتات منطقية مفحوصة. قد تمنع اختلافات المواقع والأذونات مقارنة الفحوص.
date|التاريخ
type|النوع
risk|المخاطر
parentFolder|المجلد الأب
search|بحث في الأسماء المفحوصة
sort|ترتيب
category|الفئة
all|كل الفئات
minimumMB|الحد الأدنى بالميغابايت
extension|امتداد الملف
modifiedAfter|عُدّل بعد
apply|تطبيق
scanInProgress|الفحص جارٍ. النتائج جزئية والتنظيف غير متاح.
previous|السابق
next|التالي
selectEligible|تحديد المؤهل في الصفحة
deselectPage|إلغاء تحديد الصفحة
reveal|إظهار في Finder
reviewTrash|مراجعة الملفات المحددة…
confirmTitle|نقل هذه الملفات بعينها إلى سلة المهملات؟
reviewConsequences|راجع كل مسار ونتائجه. ستُتخطى العناصر المتغيرة أو المحمية أو غير المتاحة. قد تحتوي الملفات غير المعروفة على بيانات مهمة.
moveToTrash|نقل الملفات المحددة إلى السلة
deselectAll|إلغاء تحديد الكل
permanent|حتى إزالة القاعدة
oneDay|حماية لمدة 24 ساعة
removeProtection|إزالة القاعدة
restoreWarning|الاستعادة إلى المسار الأصلي دون الكتابة فوق ملفات موجودة. لا يمكن الاستعادة بعد إفراغ السلة.
duplicateGuidance|نسخ مطابقة باستخدام SHA-256. اختر النسخ فردياً واحتفظ بواحدة على الأقل. تُستبعد الروابط الصلبة والملفات السحابية. لا يمكن تحديد كتل APFS المشتركة.
findDuplicates|البحث عن نسخ مطابقة
showHidden|إظهار الملفات المخفية
translationNotice|الترجمات مسودات وتحتاج إلى مراجعة متحدثين متمكنين.
limitations|تنظيف المجلدات وأوامر الأدوات وكشف الاستخدام المباشر وتنظيف النظام تلقائياً غير متاحة. لا تُحدد البيانات غير المعروفة تلقائياً.
error|تعذر إكمال العملية
ok|موافق
allocated|تقدير المساحة المخصصة
created|تاريخ الإنشاء
modified|تاريخ التعديل
opened|آخر وصول (ليس بالضرورة فتح الملف)
owner|مالك ذاكرة التخزين المؤقت المعروف
activeUse|الاستخدام النشط
unavailable|غير متاح / لم يُثبت
recoveryNotice|الاستعادة مشروطة. لا استعادة بعد إفراغ السلة.
preview|نظرة سريعة
riskLevel.low|منخفض
risk.protected|يمنع قيد في النظام أو قاعدة حماية التنظيف.
consequence.protected|اترك هذا العنصر في مكانه.
risk.special|هذا مجلد أو رابط أو عنصر حزمة أو رابط صلب أو عنصر سحابي.
consequence.special|قد تؤثر الإزالة على مواقع أو تطبيقات أو أجهزة متزامنة أخرى. التنظيف محظور.
risk.database|قد يحتوي هذا على حالة تطبيق أو قاعدة بيانات.
consequence.database|قد يؤدي الحذف إلى فقدان بيانات التطبيق. التنظيف محظور.
risk.cache|قد يحتوي مسار تخزين مؤقت معروف على بيانات يمكن إعادة إنشائها. لم يُثبت الاستخدام النشط أو التبعيات.
consequence.cache|أغلق التطبيق المالك. قد يبطئ الحذف التحميل الأولي أو يتطلب إعادة إنشاء معاينات أو عمليات بناء أو تنزيلات.
risk.recent|عُدّل هذا الملف مؤخراً أو تاريخ تعديله غير متاح.
consequence.user|قد يزيل الحذف بيانات شخصية أو بيانات مشروع. تأكد من أنك لا تحتاج هذا الملف بعينه.
risk.unknown|لا توجد قاعدة تنظيف تثبت الغرض من هذا العنصر.
history.pending|معلق / غير مؤكد — افحص السلة يدوياً
history.trashed|نُقل إلى سلة المهملات
history.skipped|تم التخطي / فشل — راجع التفاصيل
history.uncertain|النتيجة غير مؤكدة — افحص السلة
history.restoring|الاستعادة غير مؤكدة — افحص المسار الأصلي
history.restored|تمت الاستعادة
state.idle|خامل
state.preparing|جارٍ التحضير
state.scanning|جارٍ الفحص
state.paused|متوقف مؤقتاً
state.completed|مكتمل
state.cancelled|ملغى
state.failed|فشل
category.applications|تطبيقات
category.documents|مستندات
category.images|صور
category.videos|فيديو
category.audio|صوت
category.archives|أرشيفات
category.installers|برامج تثبيت محملة
category.caches|بيانات تخزين مؤقت
category.logs|سجلات
category.backups|نسخ احتياطية
category.developer|ملفات المطور
category.support|بيانات دعم التطبيقات
category.cloud|ملفات تديرها السحابة
category.unknown|بيانات غير معروفة
''')
add('fr', '''
locations|Emplacements
allAccessible|Choisir un stockage accessible…
volumes|Volumes connectés
applications|Applications
documents|Documents
downloads|Téléchargements
desktop|Bureau
pictures|Images
movies|Vidéos
music|Musique
library|Bibliothèque
scan|Analyser
pause|Pause
resume|Reprendre
items|éléments
scanErrors|illisibles ou modifiés
seconds|secondes
welcomeSubtitle|Comprenez votre stockage. Choisissez ce qui reste.
privacy|Hors ligne et privé. Sans compte, envoi de fichiers, publicité ni télémétrie.
scanGuidance|Choisissez un dossier. L’analyse lit seulement les métadonnées. macOS peut demander une autorisation. En cas de refus, choisissez un autre dossier. L’accès complet au disque n’est pas demandé au démarrage.
diskUsage|Utilisation du volume
distribution|Répartition des dossiers
partialNotice|Affiche jusqu’à 12 grands éléments de la page actuelle. Une analyse partielle ou des fichiers inaccessibles rendent les totaux incomplets. Les clones APFS peuvent partager des blocs.
trends|Historique des analyses
trendNotice|Les totaux sont les octets logiques analysés. Des dossiers ou autorisations différents peuvent empêcher la comparaison.
date|Date
type|Type
risk|Risque
parentFolder|Dossier parent
search|Rechercher les noms analysés
sort|Trier
category|Catégorie
all|Toutes les catégories
minimumMB|Minimum en Mo
extension|Extension
modifiedAfter|Modifié après
apply|Appliquer
scanInProgress|Analyse en cours. Résultats partiels ; nettoyage indisponible.
previous|Précédent
next|Suivant
selectEligible|Sélectionner les éléments admissibles de la page
deselectPage|Désélectionner la page
reveal|Afficher dans le Finder
reviewTrash|Vérifier les fichiers sélectionnés…
confirmTitle|Déplacer ces fichiers précis vers la Corbeille ?
reviewConsequences|Vérifiez chaque chemin et les conséquences. Les éléments modifiés, protégés ou inaccessibles seront ignorés. Les fichiers inconnus peuvent contenir des données importantes.
moveToTrash|Déplacer la sélection vers la Corbeille
deselectAll|Tout désélectionner
permanent|Jusqu’à suppression de la règle
oneDay|Protéger pendant 24 heures
removeProtection|Supprimer la règle
restoreWarning|Restaurer à l’emplacement d’origine sans écraser de fichier. Si la Corbeille a été vidée, la récupération est impossible.
duplicateGuidance|Doublons exacts par SHA-256. Choisissez chaque copie et conservez-en au moins une. Les liens physiques et fichiers cloud sont exclus. Les blocs APFS partagés ne sont pas identifiables.
findDuplicates|Rechercher les doublons exacts
showHidden|Afficher les fichiers cachés
translationNotice|Les traductions sont provisoires et doivent être relues par des locuteurs compétents.
limitations|Le nettoyage des dossiers, les commandes d’outils, la détection d’utilisation active et le nettoyage automatique du système sont indisponibles. Les données inconnues ne sont jamais sélectionnées automatiquement.
error|Impossible de terminer l’opération
ok|OK
allocated|Estimation de l’espace alloué
created|Création
modified|Modification
opened|Dernier accès (pas nécessairement une ouverture)
owner|Propriétaire du cache identifié
activeUse|Utilisation active
unavailable|Indisponible / non établi
recoveryNotice|La récupération est conditionnelle et impossible après vidage de la Corbeille.
preview|Coup d’œil
riskLevel.low|Faible
risk.protected|Une restriction système ou une règle de protection empêche le nettoyage.
consequence.protected|Laissez cet élément en place.
risk.special|Il s’agit d’un dossier, lien, élément de paquet, lien physique ou fichier cloud.
consequence.special|La suppression pourrait affecter d’autres emplacements, applications ou appareils synchronisés. Nettoyage bloqué.
risk.database|Cet élément peut contenir l’état d’une application ou une base de données.
consequence.database|La suppression peut perdre des données d’application. Nettoyage bloqué.
risk.cache|Un chemin de cache reconnu peut contenir des données régénérables. L’utilisation active et les dépendances ne sont pas établies.
consequence.cache|Fermez l’application concernée. La suppression peut ralentir les premiers chargements ou nécessiter de régénérer aperçus, compilations ou téléchargements.
risk.recent|Ce fichier a été modifié récemment ou sa date de modification est indisponible.
consequence.user|La suppression peut perdre des données personnelles ou de projet. Confirmez que ce fichier précis est inutile.
risk.unknown|Aucune règle de nettoyage ne permet d’établir l’usage de cet élément.
history.pending|En attente / incertain — inspectez la Corbeille
history.trashed|Déplacé vers la Corbeille
history.skipped|Ignoré / échec — consultez les détails
history.uncertain|Résultat incertain — inspectez la Corbeille
history.restoring|Restauration incertaine — inspectez le chemin d’origine
history.restored|Restauré
state.idle|Inactif
state.preparing|Préparation
state.scanning|Analyse
state.paused|En pause
state.completed|Terminé
state.cancelled|Annulé
state.failed|Échec
category.applications|Applications
category.documents|Documents
category.images|Images
category.videos|Vidéos
category.audio|Audio
category.archives|Archives
category.installers|Programmes d’installation téléchargés
category.caches|Caches temporaires
category.logs|Journaux
category.backups|Sauvegardes
category.developer|Fichiers de développement
category.support|Données d’application
category.cloud|Fichiers gérés dans le cloud
category.unknown|Données inconnues
''')
add('zh-Hans', '''
locations|位置
allAccessible|选择可访问的存储位置…
volumes|已挂载的卷
applications|应用程序
documents|文稿
downloads|下载
desktop|桌面
pictures|图片
movies|影片
music|音乐
library|资源库
scan|扫描
pause|暂停
resume|继续
items|项目
scanErrors|无法读取或已更改
seconds|秒
welcomeSubtitle|了解存储空间，选择保留的内容。
privacy|离线且保护隐私。无需账户、上传文件、广告或遥测。
scanGuidance|选择要扫描的文件夹。扫描只读取元数据。macOS 可能会请求权限。如果访问被拒绝，请选择其他可访问的文件夹。启动时不会请求完全磁盘访问权限。
diskUsage|卷使用情况
distribution|文件夹分布
partialNotice|显示当前页面中最多12个最大项目。部分扫描和无法访问的文件会导致总计不完整。APFS 克隆可能共享存储块。
trends|扫描历史
trendNotice|总计为扫描的逻辑字节数。不同的根目录和访问限制可能使扫描结果无法比较。
date|日期
type|类型
risk|风险
parentFolder|上级文件夹
search|搜索已扫描的名称
sort|排序
category|类别
all|所有类别
minimumMB|最小 MB
extension|扩展名
modifiedAfter|修改日期晚于
apply|应用
scanInProgress|正在扫描。结果尚不完整，无法清理。
previous|上一页
next|下一页
selectEligible|选择本页符合条件的项目
deselectPage|取消选择本页
reveal|在 Finder 中显示
reviewTrash|检查所选文件…
confirmTitle|将这些确切的文件移到废纸篓？
reviewConsequences|请检查每个路径和删除后果。已更改、受保护或无法访问的项目将被跳过。未知文件可能包含重要数据。
moveToTrash|将所选文件移到废纸篓
deselectAll|取消全选
permanent|直到移除规则
oneDay|保护24小时
removeProtection|移除规则
restoreWarning|恢复到原始路径，不覆盖现有文件。如果废纸篓已被清空，则无法恢复。
duplicateGuidance|通过 SHA-256 检测完全相同的文件。请逐个选择副本并至少保留一个。硬链接和云端文件不参与比较。无法识别 APFS 共享块。
findDuplicates|查找完全相同的文件
showHidden|显示隐藏文件
translationNotice|翻译为草稿，需要流利使用该语言的人员审核。
limitations|暂不提供文件夹清理、工具命令、实时使用检测和自动系统清理。绝不会自动选择未知数据。
error|无法完成操作
ok|好
allocated|分配空间估计值
created|创建时间
modified|修改时间
opened|最后访问时间（不一定是打开时间）
owner|识别出的缓存所属应用
activeUse|正在使用
unavailable|不可用／未确认
recoveryNotice|恢复有条件。清空废纸篓后无法恢复。
preview|快速查看
riskLevel.low|低
risk.protected|系统限制或保护规则阻止清理。
consequence.protected|请保留此项目。
risk.special|这是文件夹、链接、软件包项目、硬链接或云端管理的项目。
consequence.special|移除可能影响其他位置、应用程序或同步设备。已阻止清理。
risk.database|此项目可能包含应用程序状态或数据库。
consequence.database|删除可能导致应用程序数据丢失。已阻止清理。
risk.cache|已识别的缓存路径可能包含可重新生成的数据，但无法确认是否正在使用或存在依赖关系。
consequence.cache|请关闭所属应用。删除可能导致首次加载变慢，或需要重新生成预览、构建结果或下载内容。
risk.recent|此文件最近被修改，或无法获取修改日期。
consequence.user|删除可能导致个人或项目数据丢失。请确认不再需要这个确切的文件。
risk.unknown|没有明确的清理规则可以确认此项目的用途。
history.pending|等待中／不确定 — 请手动检查废纸篓
history.trashed|已移到废纸篓
history.skipped|已跳过／失败 — 请查看详情
history.uncertain|结果不确定 — 请检查废纸篓
history.restoring|恢复结果不确定 — 请检查原始路径
history.restored|已恢复
state.idle|空闲
state.preparing|准备中
state.scanning|扫描中
state.paused|已暂停
state.completed|已完成
state.cancelled|已取消
state.failed|失败
category.applications|应用程序
category.documents|文稿
category.images|图片
category.videos|视频
category.audio|音频
category.archives|压缩文件
category.installers|已下载的安装程序
category.caches|临时缓存
category.logs|日志
category.backups|备份
category.developer|开发者文件
category.support|应用程序支持数据
category.cloud|云端管理的文件
category.unknown|未知数据
''')
