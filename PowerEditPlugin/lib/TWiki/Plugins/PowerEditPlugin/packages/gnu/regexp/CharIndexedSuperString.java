package gnu.regexp;

import uk.co.cdot.SuperString;

class CharIndexedSuperString implements CharIndexed {
  private SuperString s;
  private int m_index;

  CharIndexedSuperString(SuperString str, int index) {
    s = str;
    m_index = index;
  }

  public char charAt(int index) {
    return ((m_index + index) < s.length()) ? s.charAt(m_index + index) : CharIndexed.OUT_OF_BOUNDS;
  }

  public boolean isValid() {
    return (m_index < s.length());
  }

  public boolean move(int index) {
    return ((m_index += index) < s.length());
  }
}
