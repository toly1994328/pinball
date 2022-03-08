part of 'theme_cubit.dart';

class ThemeState extends Equatable {
  const ThemeState(this.theme);

  const ThemeState.initial()
      : theme = const PinballTheme(characterTheme: DashTheme());

  final PinballTheme theme;

  @override
  List<Object> get props => [theme];
}