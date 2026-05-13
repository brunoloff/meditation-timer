part of 'main.dart';

class AcknowledgementsScreen extends StatelessWidget {
  const AcknowledgementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AcknowledgementsTitleBar(
              onCancel: () => Navigator.of(context).pop(),
            ),
            const Divider(height: 1, thickness: 1, color: _dividerColor),
            Expanded(
              child: ColoredBox(
                color: _homeSurfaceColor,
                child: ListView(
                  key: const ValueKey('acknowledgements-scroll-view'),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
                  children: [
                    _AcknowledgementParagraph(
                      spans: [
                        TextSpan(text: 'I have used the '),
                        _LinkedAcknowledgementSpan(
                          text: 'Insight Timer app',
                          url:
                              'https://play.google.com/store/apps/details?id=com.spotlightsix.zentimerlite2&pcampaignid=web_share',
                        ),
                        TextSpan(
                          text:
                              ' for many years before deciding to make my own. The app has a lot of guided meditations and other features which I do not want, and it is missing a pranayama timer, which I did want.',
                        ),
                      ],
                    ),
                    _AcknowledgementParagraph(
                      spans: [
                        TextSpan(
                          text:
                              'Thank you to Forrest Knutson for his excellent pranayama lessons. Here is a link to his ',
                        ),
                        _LinkedAcknowledgementSpan(
                          text: 'YouTube channel',
                          url:
                              'https://www.youtube.com/channel/UCcXwc0ArDa6a2ew5nFyFFDQ',
                        ),
                        TextSpan(text: '.'),
                      ],
                    ),
                    _AcknowledgementParagraph(
                      spans: [
                        TextSpan(
                          text:
                              'Thank you to Daniel Ingram for his excellent book, ',
                        ),
                        _LinkedAcknowledgementSpan(
                          text: 'available for free online',
                          url: 'https://www.integrateddaniel.info/book',
                        ),
                        TextSpan(text: '.'),
                      ],
                    ),
                    _AcknowledgementParagraph(
                      text:
                          'Thank you to various excellent teachers and dharma friends, such as (in order of my own personal chronology), Henepola Gunaratana, S.N. Goenka, Daniel Ingram, Tarin Greco, Kenneth Folk, John Wilde (Patrick), Leigh Brasington, Matt Harvey, Claralynn Nunamaker, Vince Horn, Brian Newman, Emily Horn. Thank you also to the more sociopathic/narcissistic gurus that crossed my way, especially Richard of Actual Freedom, for providing their very own special kind of insight.',
                    ),
                    _AcknowledgementParagraph(
                      text:
                          'And finally, thank you to Codex for coding this excellent app, which would have taken me hundreds of hours but took Codex about 10. The app should more truthfully be called "Codex\'s" Meditation Timer", but we agreed that the unfair choice of "Bruno\'s" sounded more catchy, and that (quoting Codex himself) “Codex’s Meditation Timer” sounds like it might ask you to accept terms before breathing out".',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcknowledgementsTitleBar extends StatelessWidget {
  const _AcknowledgementsTitleBar({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 8,
            child: IconButton(
              key: const ValueKey('close-acknowledgements-button'),
              onPressed: onCancel,
              tooltip: 'Close',
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          const Text(
            'Acknowledgements',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AcknowledgementParagraph extends StatelessWidget {
  const _AcknowledgementParagraph({this.text, this.spans = const []});

  final String? text;
  final List<InlineSpan> spans;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: RichText(
        text: TextSpan(
          text: text,
          children: spans,
          style: const TextStyle(
            color: Color(0xFFE6E6EA),
            fontSize: 16,
            height: 1.45,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _LinkedAcknowledgementSpan extends WidgetSpan {
  _LinkedAcknowledgementSpan({required String text, required String url})
    : super(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () => unawaited(_openAcknowledgementUrl(url)),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF8EDDD0),
              fontSize: 16,
              height: 1.45,
              letterSpacing: 0,
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFF8EDDD0),
            ),
          ),
        ),
      );
}

Future<void> _openAcknowledgementUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } on Object {
    // Acknowledgement links are nice-to-have; failure should not interrupt the
    // screen or throw from a recognizer callback.
  }
}
