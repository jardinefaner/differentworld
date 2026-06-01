/// A tiny, safe arithmetic evaluator for the Math inverse archetype
/// (docs/ACTIVITY_RUNTIME.md §6) — recursive descent over `+ - * / ( )`
/// with unary minus and decimals. Accepts the kid-friendly glyphs `×`,
/// `÷`, and the typographic minus `−`/`–` as aliases.
///
/// Pure, deterministic, offline — kid-level arithmetic. This is the
/// hardcoded *capability* that math validation rests on: computation is a
/// capability, never a data-rule (SEMANTIC_GRAPH.md §2 — the closed rule
/// vocabulary is intentionally not Turing-complete, so anything that needs
/// real evaluation lives here, in code, not in a rule row).
///
/// Throws [FormatException] on malformed input (the validator turns that
/// into `valid: false`). It never executes anything but arithmetic — there
/// is no code-eval surface.
double evaluateExpression(String input) => _Parser(input).parse();

class _Parser {
  _Parser(String src)
    : _s = src
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('−', '-') // U+2212 minus sign
          .replaceAll('–', '-'), // en dash, a common typo
      _i = 0;

  final String _s;
  int _i;

  double parse() {
    final v = _expr();
    _skip();
    if (_i != _s.length) {
      throw FormatException('trailing input at $_i', _s);
    }
    return v;
  }

  void _skip() {
    while (_i < _s.length && _s[_i] == ' ') {
      _i++;
    }
  }

  double _expr() {
    var v = _term();
    while (true) {
      _skip();
      if (_i >= _s.length) break;
      final c = _s[_i];
      if (c == '+') {
        _i++;
        v += _term();
      } else if (c == '-') {
        _i++;
        v -= _term();
      } else {
        break;
      }
    }
    return v;
  }

  double _term() {
    var v = _factor();
    while (true) {
      _skip();
      if (_i >= _s.length) break;
      final c = _s[_i];
      if (c == '*') {
        _i++;
        v *= _factor();
      } else if (c == '/') {
        _i++;
        final d = _factor();
        if (d == 0) throw FormatException('division by zero', _s);
        v /= d;
      } else {
        break;
      }
    }
    return v;
  }

  double _factor() {
    _skip();
    if (_i >= _s.length) throw FormatException('unexpected end', _s);
    final c = _s[_i];
    if (c == '(') {
      _i++;
      final v = _expr();
      _skip();
      if (_i >= _s.length || _s[_i] != ')') {
        throw FormatException('expected )', _s);
      }
      _i++;
      return v;
    }
    if (c == '-') {
      _i++;
      return -_factor();
    }
    if (c == '+') {
      _i++;
      return _factor();
    }
    return _number();
  }

  double _number() {
    _skip();
    final start = _i;
    while (_i < _s.length && (_isDigit(_s[_i]) || _s[_i] == '.')) {
      _i++;
    }
    if (_i == start) throw FormatException('expected number at $_i', _s);
    final n = double.tryParse(_s.substring(start, _i));
    if (n == null) throw FormatException('bad number at $start', _s);
    return n;
  }

  bool _isDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 48 && u <= 57;
  }
}
