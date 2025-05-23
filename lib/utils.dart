List<String> getSyllable(String label, String burmeseConsonant, String others) {
  RegExp regExp = RegExp(
    r"(?<![္])([" + burmeseConsonant + r"])(?![်္ ့])|([" + others + r"])",
    unicode: true,
  );

  String regLabel =
      label.replaceAllMapped(regExp, (match) {
        // Ensure null safety for optional groups
        String part1 = match.group(1) ?? "";
        String part2 = match.group(2) ?? "";
        return " $part1$part2";
      }).trim();

  RegExp regExp2 = RegExp(r"([က-ၴ])([a-zA-Z0-9])", unicode: true);

  regLabel = regLabel.replaceAllMapped(regExp2, (match) {
    return "${match.group(1)} ${match.group(2)}";
  });

  RegExp regExp3 = RegExp(r'([0-9၀-၉])\s+([0-9၀-၉])\s*', unicode: true);

  regLabel = regLabel.replaceAllMapped(regExp3, (match) {
    return "${match.group(1)}${match.group(2)}";
  });

  RegExp regExp4 = RegExp(r'([0-9၀-၉])\s+(\+)', unicode: true);

  regLabel =
      regLabel.replaceAllMapped(regExp4, (match) {
        return "${match.group(1)}${match.group(2)}";
      }).trim();

  return regLabel.split(' ');
}

List<String> syllableSplit(String label) {
  String burmeseConsonant = 'ကခဂဃငစဆဇဈညဉဋဌဍဎဏတထဒဓနပဖဗဘမယရလဝသဟဠအ';
  String others = r'ဣဤဥဦဧဩဪဿ၌၍၏၀-၉၊။!-/:-@[-`{-~\s.,';

  return label
      .split(' ')
      .expand((word) => [...getSyllable(word, burmeseConsonant, others)])
      .toList();

  // return getSyllable(label, burmeseConsonant, others);
  // return labelSyllable.sublist(0, labelSyllable.length - 1);
}

List<String> maximumMatching(
  List<String> syllables,
  Map<String, String> dictionary,
) {
  List<String> tokens = [];
  int i = 0;
  int maxLen =
      dictionary.keys.isEmpty
          ? 1 // Default to 1 if dictionary is empty
          : dictionary.keys
              .map((word) => word.length)
              .reduce((a, b) => a > b ? a : b);

  while (i < syllables.length) {
    bool matched = false;
    for (int length = maxLen; length > 0; length--) {
      if (i + length <= syllables.length) {
        String candidate = syllables.sublist(i, i + length).join();
        if (dictionary.containsKey(candidate)) {
          tokens.add(candidate);
          i += length;
          matched = true;
          break;
        }
      }
    }
    if (!matched) {
      tokens.add(syllables[i]);
      i++;
    }
  }
  return tokens;
}
