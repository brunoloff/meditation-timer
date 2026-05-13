import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'timer_data.dart';
part 'pranayama_data.dart';
part 'background_timer_service.dart';
part 'main_screen.dart';
part 'tabs.dart';
part 'pranayama_tab.dart';
part 'edit_timer_screen.dart';
part 'select_sound_screen.dart';
part 'meditation_screen.dart';
part 'meditation_logs.dart';
part 'logs_screen.dart';
part 'acknowledgements_screen.dart';

void main() {
  runApp(const BreathAndInsightTimerApp());
}

class BreathAndInsightTimerApp extends StatelessWidget {
  const BreathAndInsightTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Bruno's Meditation Timer",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Colors.black,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

Future<void> _configurePlayerForAudioMixing(AudioPlayer player) async {
  try {
    await player.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
    );
  } on MissingPluginException {
    return;
  } on UnimplementedError {
    return;
  } on Object {
    return;
  }
}
