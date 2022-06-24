import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame_bloc/flame_bloc.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:leaderboard_repository/leaderboard_repository.dart';
import 'package:pinball/game/behaviors/behaviors.dart';
import 'package:pinball/game/game.dart';
import 'package:pinball/l10n/l10n.dart';
import 'package:pinball/select_character/select_character.dart';
import 'package:pinball_audio/pinball_audio.dart';
import 'package:pinball_components/pinball_components.dart';
import 'package:pinball_flame/pinball_flame.dart';
import 'package:platform_helper/platform_helper.dart';
import 'package:share_repository/share_repository.dart';

class PinballGame extends PinballForge2DGame
    with HasKeyboardHandlerComponents, MultiTouchTapDetector, HasTappables {
  PinballGame({
    required CharacterThemeCubit characterThemeBloc,
    required this.leaderboardRepository,
    required this.shareRepository,
    required GameBloc gameBloc,
    required AppLocalizations l10n,
    required PinballAudioPlayer audioPlayer,
    required this.platformHelper,
  })  : focusNode = FocusNode(),
        _gameBloc = gameBloc,
        _audioPlayer = audioPlayer,
        _characterThemeBloc = characterThemeBloc,
        _l10n = l10n,
        super(
          gravity: Vector2(0, 30),
        ) {
    images.prefix = '';
  }

  /// Identifier of the play button overlay.
  static const playButtonOverlay = 'play_button';

  /// Identifier of the replay button overlay.
  static const replayButtonOverlay = 'replay_button';

  /// Identifier of the mobile controls overlay.
  static const mobileControlsOverlay = 'mobile_controls';

  @override
  Color backgroundColor() => Colors.transparent;

  final FocusNode focusNode;

  final CharacterThemeCubit _characterThemeBloc;

  final PinballAudioPlayer _audioPlayer;

  final LeaderboardRepository leaderboardRepository;

  final ShareRepository shareRepository;

  final AppLocalizations _l10n;

  final PlatformHelper platformHelper;

  final GameBloc _gameBloc;

  List<LeaderboardEntryData>? _entries;

  Future<void> preFetchLeaderboard() async {
    try {
      _entries = await leaderboardRepository.fetchTop10Leaderboard();
    } catch (_) {
      // An initial null leaderboard means that we couldn't fetch
      // the entries for the [Backbox] and it will show the relevant display.
      _entries = null;
    }
  }

  @override
  Future<void> onLoad() async {
    await add(
      FlameMultiBlocProvider(
        providers: [
          FlameBlocProvider<GameBloc, GameState>.value(
            value: _gameBloc,
          ),
          FlameBlocProvider<CharacterThemeCubit, CharacterThemeState>.value(
            value: _characterThemeBloc,
          ),
        ],
        children: [
          MultiFlameProvider(
            providers: [
              FlameProvider<PinballAudioPlayer>.value(_audioPlayer),
              FlameProvider<LeaderboardRepository>.value(leaderboardRepository),
              FlameProvider<ShareRepository>.value(shareRepository),
              FlameProvider<AppLocalizations>.value(_l10n),
              FlameProvider<PlatformHelper>.value(platformHelper),
            ],
            children: [
              BonusNoiseBehavior(),
              GameBlocStatusListener(),
              BallSpawningBehavior(),
              CharacterSelectionBehavior(),
              CameraFocusingBehavior(),
              CanvasComponent(
                onSpritePainted: (paint) {
                  if (paint.filterQuality != FilterQuality.medium) {
                    paint.filterQuality = FilterQuality.medium;
                  }
                },
                children: [
                  ZCanvasComponent(
                    children: [
                      if (!platformHelper.isMobile) ArcadeBackground(),
                      BoardBackgroundSpriteComponent(),
                      Boundaries(),
                      Backbox(
                        leaderboardRepository: leaderboardRepository,
                        shareRepository: shareRepository,
                        entries: _entries,
                      ),
                      GoogleGallery(),
                      Multipliers(),
                      Multiballs(),
                      SkillShot(
                        children: [
                          ScoringContactBehavior(points: Points.oneMillion),
                          RolloverNoiseBehavior(),
                        ],
                      ),
                      AndroidAcres(),
                      DinoDesert(),
                      FlutterForest(),
                      SparkyScorch(),
                      Drain(),
                      BottomGroup(),
                      Launcher(),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await super.onLoad();
  }

  final focusedBoardSide = <int, BoardSide>{};

  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    if (info.raw.kind == PointerDeviceKind.touch &&
        _gameBloc.state.status.isPlaying) {
      final rocket = descendants().whereType<RocketSpriteComponent>().first;
      final bounds = rocket.topLeftPosition & rocket.size;

      final tappedRocket = bounds.contains(info.eventPosition.game.toOffset());
      if (tappedRocket) {
        descendants()
            .whereType<FlameBlocProvider<PlungerCubit, PlungerState>>()
            .first
            .bloc
            .autoPulled();
      } else {
        final tappedLeftSide = info.eventPosition.widget.x < canvasSize.x / 2;
        focusedBoardSide[pointerId] =
            tappedLeftSide ? BoardSide.left : BoardSide.right;
        final flippers = descendants()
            .whereType<Flipper>()
            .where((flipper) => flipper.side == focusedBoardSide[pointerId]);
        for (final flipper in flippers) {
          flipper
              .descendants()
              .whereType<FlameBlocProvider<FlipperCubit, FlipperState>>()
              .forEach((provider) => provider.bloc.moveUp());
        }
      }
    }

    super.onTapDown(pointerId, info);
  }

  @override
  void onTapUp(int pointerId, TapUpInfo info) {
    _moveFlippersDown(pointerId);
    super.onTapUp(pointerId, info);
  }

  @override
  void onTapCancel(int pointerId) {
    _moveFlippersDown(pointerId);
    super.onTapCancel(pointerId);
  }

  void _moveFlippersDown(int pointerId) {
    if (focusedBoardSide[pointerId] != null) {
      final flippers = descendants()
          .whereType<Flipper>()
          .where((flipper) => flipper.side == focusedBoardSide[pointerId]);
      for (final flipper in flippers) {
        flipper
            .descendants()
            .whereType<FlameBlocProvider<FlipperCubit, FlipperState>>()
            .forEach((provider) => provider.bloc.moveDown());
      }
    }
  }
}

