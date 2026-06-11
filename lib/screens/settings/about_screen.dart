import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../providers/theme_provider.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _yasirEnExpanded = true;
  bool _yasirArExpanded = true;

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final l10n = context.l10n;
    final sections = l10n.isArabic
        ? [_arabicSection(th), _englishSection(th)]
        : [_englishSection(th), _arabicSection(th)];

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        backgroundColor: th.bg,
        leading: BackButton(color: th.textPrimary),
        title: Text(
          l10n.aboutApp,
          style: TextStyle(color: th.textPrimary, fontSize: 16),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemBuilder: (context, index) => sections[index],
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemCount: sections.length,
      ),
    );
  }

  Widget _englishSection(AppTheme th) {
    return _block(
      th,
      TextDirection.ltr,
      [
        _greeting(th, 'Assalamu Alaikum wa Rahmatullahi wa Barakatuh.'),
        const SizedBox(height: 16),
        _heading(th, 'What Yalla Arabic Is'),
        _body(
          th,
          'Yalla Arabic is built for English speakers who want to learn Modern '
          'Standard Arabic, Al-Fusha, through listening-first lessons. Listen '
          'to Arabic you can understand, repeat it often, and let the language '
          'start to feel natural before worrying about rules.',
        ),
        _body(
          th,
          'Use the Home tab for the main course lessons, the Review tab to '
          'practise saved words and phrases, and Settings to adjust the player, '
          'translation, downloads, language, and daily goal.',
        ),
        _heading(th, 'How to Use Each Lesson'),
        _body(
          th,
          'Open a lesson and work through the lesson types in order. Do not jump '
          'straight to vocabulary before you have listened to the main content. '
          'Listen to each recording more than once. Your brain notices patterns '
          'through repeated, understandable Arabic.',
        ),
        _body(
          th,
          'Keep the Arabic transcript open while you listen. Use the English '
          'translation when you need help, then return your attention to the '
          'Arabic audio. If a sentence feels fast, replay it or slow the audio '
          'down from the player.',
        ),
        _heading(th, 'App Controls and Player Controls'),
        _bullet(
          th,
          'Play and pause',
          'Use the main player button to start or pause the current audio.',
        ),
        _bullet(
          th,
          'Speed control',
          'Adjust playback speed when the audio is too fast or when you want '
              'more challenge.',
        ),
        _bullet(
          th,
          'Transcript auto-scroll',
          'The active transcript line is highlighted and follows the audio so '
              'you can keep your place.',
        ),
        _bullet(
          th,
          'Tap any word',
          'Open a word popup with the available meaning, example, pronunciation, '
              'forms, and translation help.',
        ),
        _bullet(
          th,
          'Speaker icon in the word popup',
          'Hear the word pronounced. You can adjust pronunciation speed in the '
              'player settings.',
        ),
        _bullet(
          th,
          'Auto-play in player settings',
          'Start audio automatically when a lesson opens.',
        ),
        _bullet(
          th,
          'Pause on word tap',
          'Pause the audio when you tap a word so you can read the popup.',
        ),
        _bullet(
          th,
          'Loop button',
          'Repeat the whole audio once or keep it looping.',
        ),
        _bullet(
          th,
          'Moon icon',
          'Set a sleep timer for 15, 30, 45, or 60 minutes.',
        ),
        _bullet(
          th,
          'Download icon',
          'Save lessons for offline listening.',
        ),
        _bullet(
          th,
          'Downloads in Settings',
          'Manage saved lessons and free space on your device.',
        ),
        _heading(th, 'Transcript and Translation Help'),
        _body(
          th,
          'The Arabic transcript is the main guide. Read it while the audio '
          'plays, notice the highlighted sentence, and replay lines that feel '
          'important. The transcript is there to make the audio understandable, '
          'not to replace listening.',
        ),
        _body(
          th,
          'The English translation is support. Turn it on when meaning is not '
          'clear, then try listening again with your attention on the Arabic. '
          'Settings also let you adjust Arabic and English text size.',
        ),
        _heading(th, 'Saved Words, Phrases, and Review'),
        _body(
          th,
          'Star lessons or save words and phrases you want to see again. The '
          'Review tab turns saved material into practice so you can test '
          'yourself without leaving the listening-first method.',
        ),
        _body(
          th,
          'The review quiz shows an Arabic prompt and English answer choices. '
          'Choose a level from A1, A2, B1, B2, or All, choose the number of '
          'questions, then practise. Use the score and feedback to decide what '
          'to listen to again.',
        ),
        _heading(th, 'Why Comprehensible Input Works'),
        _body(
          th,
          'Languages become usable when you hear messages that you mostly '
          'understand many times. Grammar explanations can help, but they should '
          'support listening. The core is simple: clear Arabic, enough meaning, '
          'and many hours of exposure.',
        ),
        _storyCard(
          th,
          title: 'Yasir\'s Story: Put in the Hours',
          isExpanded: _yasirEnExpanded,
          onTap: () => setState(() => _yasirEnExpanded = !_yasirEnExpanded),
          isArabic: false,
          body:
              'Why do I think this app can work when there are already hundreds '
              'of language apps?\n\n'
              'Because it is built around comprehensible input: learning by '
              'listening to language you can mostly understand, again and again, '
              'until the language starts to feel natural.\n\n'
              'I saw this work up close. My Egyptian friend Yasir went from '
              'around A1 to C1 in English through the same listening-first '
              'method that inspired this app. But the key was not a trick or a '
              'shortcut. The key was the hours.\n\n'
              'He listened for around 915 hours over six months, woven into '
              'normal life: driving, walking, the gym, and waiting around. Five '
              'or six hours a day adds up fast when the audio is always with '
              'you.\n\n'
              'Now his English is strong enough that he teaches Arabic on '
              'Preply in English. He even told me he dreams in English '
              'sometimes.\n\n'
              'That proves the comprehensible input method can work when the '
              'learner gets enough understandable audio. Yalla Arabic now uses '
              'the same listening-first idea for Arabic: clear Arabic, repeated '
              'many times, with English support only when you need it.',
        ),
        _heading(th, 'Accuracy and Known Issues'),
        _body(
          th,
          'The transcript may occasionally start a few seconds late or drift '
          'slightly out of sync with the audio. You may also find occasional '
          'spelling or translation mistakes. Use the transcript, popup, and '
          'translation together to double-check meaning.',
        ),
        _heading(th, 'A Note on Some Content'),
        _body(
          th,
          'Some learning material may not fully match your values or interests. '
          'Skip any lesson that does not help you. The goal is to give you as '
          'much understandable Arabic listening as possible.',
        ),
        _heading(th, 'What to Do After This App'),
        _body(
          th,
          'Keep feeding your ears every day. Listen to Arabic stories, shows, '
          'podcasts, news, lessons, or anything you enjoy and can mostly follow. '
          'When you practise speaking, choose patient speakers and keep the '
          'conversation mostly in Arabic.',
        ),
        _heading(th, 'Share the App'),
        _body(
          th,
          'If this app helps you, share it freely. More listening helps more '
          'learners.',
        ),
        _heading(th, 'Special Thanks'),
        _body(
          th,
          'Special thanks to Yasir Salah for the idea, and to everyone who '
          'supported this project.',
        ),
        _heading(th, 'About Palestine'),
        _body(
          th,
          'Boycott where you can. Donate where you can. Remember them in your '
          'prayers.',
        ),
        Center(
          child: Text(
            'Free Palestine!',
            style: TextStyle(
              color: th.accent,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _arabicSection(AppTheme th) {
    return _block(
      th,
      TextDirection.rtl,
      [
        _greeting(th, 'السلام عليكم ورحمة الله وبركاته.', isArabic: true),
        const SizedBox(height: 16),
        _heading(th, 'ما هو يلا عربي', isArabic: true),
        _body(
          th,
          'يلا عربي تطبيق لمتحدثي الإنجليزية الذين يريدون تعلّم العربية '
          'الفصحى من خلال الاستماع أولاً. استمع إلى عربية مفهومة، وكررها '
          'كثيراً، ودع اللغة تصبح طبيعية في أذنك قبل الانشغال بالقواعد.',
          isArabic: true,
        ),
        _body(
          th,
          'استخدم تبويب الرئيسية للدورات الأساسية، وتبويب المراجعة للتدرب على '
          'الكلمات والعبارات المحفوظة، والإعدادات لضبط المشغّل والترجمة '
          'والتنزيلات ولغة التطبيق والهدف اليومي.',
          isArabic: true,
        ),
        _heading(th, 'كيفية استخدام كل درس', isArabic: true),
        _body(
          th,
          'افتح الدرس واتبع أنواعه بالترتيب. لا تنتقل مباشرة إلى المفردات قبل '
          'الاستماع إلى المحتوى الرئيسي. استمع إلى كل تسجيل أكثر من مرة. '
          'العقل يلتقط الأنماط من العربية المفهومة والمتكررة.',
          isArabic: true,
        ),
        _body(
          th,
          'اترك النص العربي أمامك أثناء الاستماع. استخدم الترجمة الإنجليزية '
          'عندما تحتاج إلى مساعدة، ثم أعد انتباهك إلى الصوت العربي. إذا كانت '
          'الجملة سريعة، أعدها أو خفّض سرعة الصوت من المشغّل.',
          isArabic: true,
        ),
        _heading(th, 'أدوات التطبيق والمشغّل', isArabic: true),
        _bullet(
          th,
          'التشغيل والإيقاف',
          'استخدم زر المشغّل الرئيسي لبدء الصوت الحالي أو إيقافه مؤقتاً.',
          isArabic: true,
        ),
        _bullet(
          th,
          'التحكم في السرعة',
          'غيّر سرعة التشغيل عندما يكون الصوت سريعاً أو عندما تريد تحدياً أكبر.',
          isArabic: true,
        ),
        _bullet(
          th,
          'التمرير التلقائي للنص',
          'يتم تمييز السطر الحالي ويتحرك النص مع الصوت حتى لا تضيع في الدرس.',
          isArabic: true,
        ),
        _bullet(
          th,
          'اضغط على أي كلمة',
          'افتح نافذة للكلمة تعرض المعنى المتاح، والمثال، والنطق، والأشكال، '
              'ومساعدة في الترجمة.',
          isArabic: true,
        ),
        _bullet(
          th,
          'أيقونة الصوت في نافذة الكلمة',
          'استمع إلى نطق الكلمة. يمكنك ضبط سرعة النطق من إعدادات المشغّل.',
          isArabic: true,
        ),
        _bullet(
          th,
          'التشغيل التلقائي في إعدادات المشغّل',
          'ابدأ الصوت تلقائياً عند فتح الدرس.',
          isArabic: true,
        ),
        _bullet(
          th,
          'الإيقاف عند الضغط على كلمة',
          'أوقف الصوت عند الضغط على كلمة حتى تستطيع قراءة النافذة.',
          isArabic: true,
        ),
        _bullet(
          th,
          'زر التكرار',
          'كرّر الصوت كاملاً مرة واحدة أو اجعله يتكرر باستمرار.',
          isArabic: true,
        ),
        _bullet(
          th,
          'أيقونة القمر',
          'اضبط مؤقت النوم على ١٥ أو ٣٠ أو ٤٥ أو ٦٠ دقيقة.',
          isArabic: true,
        ),
        _bullet(
          th,
          'أيقونة التنزيل',
          'احفظ الدروس للاستماع دون إنترنت.',
          isArabic: true,
        ),
        _bullet(
          th,
          'التنزيلات في الإعدادات',
          'أدر الدروس المحفوظة وحرّر مساحة على جهازك.',
          isArabic: true,
        ),
        _heading(th, 'مساعدة النص والترجمة', isArabic: true),
        _body(
          th,
          'النص العربي هو الدليل الأساسي. اقرأه أثناء تشغيل الصوت، ولاحظ '
          'الجملة المميزة، وأعد الجمل المهمة. النص موجود ليجعل الصوت مفهوماً، '
          'وليس ليحل محل الاستماع.',
          isArabic: true,
        ),
        _body(
          th,
          'الترجمة الإنجليزية وسيلة دعم. شغّلها عندما لا يكون المعنى واضحاً، '
          'ثم حاول الاستماع مرة أخرى مع التركيز على العربية. يمكنك أيضاً ضبط '
          'حجم خط العربية والإنجليزية من الإعدادات.',
          isArabic: true,
        ),
        _heading(th, 'الكلمات والعبارات المحفوظة والمراجعة', isArabic: true),
        _body(
          th,
          'أضف الدروس إلى المفضلة أو احفظ الكلمات والعبارات التي تريد رؤيتها '
          'مرة أخرى. تبويب المراجعة يحوّل المواد المحفوظة إلى تدريب حتى تختبر '
          'نفسك من غير أن تترك فكرة الاستماع أولاً.',
          isArabic: true,
        ),
        _body(
          th,
          'اختبار المراجعة يعرض سؤالاً بالعربية وخيارات إجابة بالإنجليزية. '
          'اختر المستوى A1 أو A2 أو B1 أو B2 أو الكل، واختر عدد الأسئلة، ثم '
          'تدرّب. استخدم النتيجة والتغذية الراجعة لتعرف ما تحتاج إلى سماعه '
          'مرة أخرى.',
          isArabic: true,
        ),
        _heading(th, 'لماذا تعمل المدخلات المفهومة', isArabic: true),
        _body(
          th,
          'تصبح اللغة قابلة للاستخدام عندما تسمع رسائل تفهم معظمها مرات كثيرة. '
          'شرح القواعد قد يساعد، لكنه يجب أن يخدم الاستماع. الأساس بسيط: عربية '
          'واضحة، ومعنى كاف، وساعات كثيرة من التعرض للغة.',
          isArabic: true,
        ),
        _storyCard(
          th,
          title: 'قصة ياسر: ضع الساعات',
          isExpanded: _yasirArExpanded,
          onTap: () => setState(() => _yasirArExpanded = !_yasirArExpanded),
          isArabic: true,
          body: 'لماذا أعتقد أن هذا التطبيق يمكن أن ينجح مع وجود مئات تطبيقات '
              'اللغات؟\n\n'
              'لأنه مبني على المدخلات المفهومة: أن تتعلم من خلال الاستماع إلى '
              'لغة تفهم معظمها، مرة بعد مرة، حتى تبدأ اللغة بالشعور بأنها '
              'طبيعية.\n\n'
              'رأيت هذا يحدث عن قرب. صديقي المصري ياسر انتقل من مستوى A1 '
              'تقريباً إلى C1 في الإنجليزية من خلال نفس فكرة الاستماع أولاً '
              'التي ألهمت هذا التطبيق. لكن السر لم يكن حيلة ولا اختصاراً. '
              'السر كان في الساعات.\n\n'
              'استمع حوالي ٩١٥ ساعة خلال ستة أشهر، وأدخل الاستماع في حياته '
              'اليومية: أثناء القيادة، والمشي، والذهاب إلى النادي، وأوقات '
              'الانتظار. خمس أو ست ساعات يومياً تتراكم بسرعة عندما يكون الصوت '
              'معك دائماً.\n\n'
              'الآن أصبحت إنجليزيته قوية لدرجة أنه يدرّس العربية على Preply '
              'بالإنجليزية. بل أخبرني أنه أحياناً يحلم بالإنجليزية.\n\n'
              'هذا يثبت أن طريقة المدخلات المفهومة يمكن أن تعمل عندما يحصل '
              'المتعلم على ما يكفي من الصوت المفهوم. يلا عربي يستخدم الآن نفس '
              'فكرة الاستماع أولاً لتعلّم العربية: عربية واضحة، تتكرر مرات '
              'كثيرة، مع دعم بالإنجليزية عند الحاجة فقط.',
        ),
        _heading(th, 'الدقة والمشكلات المعروفة', isArabic: true),
        _body(
          th,
          'قد يبدأ النص أحياناً بعد الصوت بثوان قليلة أو يخرج توقيته عن الصوت '
          'قليلاً. وقد تجد أحياناً خطأ في الإملاء أو الترجمة. استخدم النص '
          'والنافذة والترجمة معاً للتحقق من المعنى.',
          isArabic: true,
        ),
        _heading(th, 'ملاحظة حول بعض المحتوى', isArabic: true),
        _body(
          th,
          'قد لا تناسب بعض المواد التعليمية قيمك أو اهتماماتك. تجاوز أي درس لا '
          'يساعدك. الهدف هو أن تحصل على أكبر قدر ممكن من الاستماع العربي '
          'المفهوم.',
          isArabic: true,
        ),
        _heading(th, 'ماذا تفعل بعد هذا التطبيق؟', isArabic: true),
        _body(
          th,
          'واصل تغذية أذنيك كل يوم. استمع إلى قصص عربية، أو برامج، أو بودكاست، '
          'أو أخبار، أو دروس، أو أي شيء تستمتع به وتفهم معظمه. وعندما تتدرب على '
          'الكلام، اختر متحدثين صبورين وحاول إبقاء الحديث بالعربية قدر الإمكان.',
          isArabic: true,
        ),
        _heading(th, 'شارك التطبيق', isArabic: true),
        _body(
          th,
          'إذا أفادك التطبيق، فشاركه بحرية. مزيد من الاستماع يساعد مزيداً من '
          'المتعلمين.',
          isArabic: true,
        ),
        _heading(th, 'شكر خاص', isArabic: true),
        _body(
          th,
          'شكر خاص لياسر صلاح على الفكرة، ولكل من دعم هذا المشروع.',
          isArabic: true,
        ),
        _heading(th, 'عن فلسطين', isArabic: true),
        _body(
          th,
          'قاطع ما تستطيع. تبرع بما تستطيع. اذكرهم في دعائك.',
          isArabic: true,
        ),
        Center(
          child: Text(
            'فلسطين حرة!',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: th.accent,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _block(AppTheme th, TextDirection direction, List<Widget> children) {
    final isArabic = direction == TextDirection.rtl;
    return Directionality(
      textDirection: direction,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: th.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment:
              isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _greeting(AppTheme th, String text, {bool isArabic = false}) {
    return Text(
      text,
      textAlign: isArabic ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        color: th.accent,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _heading(AppTheme th, String text, {bool isArabic = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        text,
        textAlign: isArabic ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          color: th.accent,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _body(AppTheme th, String text, {bool isArabic = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        textAlign: isArabic ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          color: th.textSub,
          fontSize: isArabic ? 14 : 13,
          height: 1.65,
        ),
      ),
    );
  }

  Widget _bullet(
    AppTheme th,
    String title,
    String body, {
    bool isArabic = false,
  }) {
    final direction = isArabic ? TextDirection.rtl : TextDirection.ltr;
    return Padding(
      padding: EdgeInsets.only(
        bottom: 8,
        left: isArabic ? 0 : 4,
        right: isArabic ? 4 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: direction,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: 5,
              left: isArabic ? 8 : 0,
              right: isArabic ? 0 : 8,
            ),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: th.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: RichText(
              textDirection: direction,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title - ',
                    style: TextStyle(
                      color: th.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: body,
                    style: TextStyle(
                      color: th.textSub,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _storyCard(
    AppTheme th, {
    required String title,
    required String body,
    required bool isExpanded,
    required VoidCallback onTap,
    required bool isArabic,
  }) {
    final direction = isArabic ? TextDirection.rtl : TextDirection.ltr;
    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: th.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: th.accent.withValues(alpha: 0.35)),
            ),
            child: Row(
              textDirection: direction,
              children: [
                Expanded(
                  child: Text(
                    title,
                    textDirection: direction,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: TextStyle(
                      color: th.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: th.accent,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: th.accent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: th.accent.withValues(alpha: 0.15)),
            ),
            child: Text(
              body,
              textDirection: direction,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: TextStyle(
                color: th.textSub,
                fontSize: isArabic ? 14 : 13,
                height: 1.65,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
