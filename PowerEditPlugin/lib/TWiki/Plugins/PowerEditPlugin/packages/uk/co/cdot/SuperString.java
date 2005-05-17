package uk.co.cdot;

import java.io.CharArrayReader;
import java.io.Reader;
import java.util.Enumeration;
import gnu.regexp.*;

/**
 * Replacement for StringBuffer, which in JDK1.1 doesn't implement replace.
 * This is largely copied from the JDK1.2 implementation and is therefore
 * Copyright (C) Sun Microsystems
 */
public class SuperString {
    private char[] value;
    private int count;

    public SuperString() {
	this(16);
    }

    public SuperString(int length) {
	value = new char[length];
    }

    public SuperString(String str) {
	this(str.length() + 16);
	append(str);
    }

    private SuperString(SuperString s, int start, int end) {
	this(end - start);
	count = end - start;
	System.arraycopy(s.value, start, value, 0, count);
    }

    public SuperString supersub(int a, int b) {
	return new SuperString(this, a, b);
    }

    public int length() {
	return count;
    }

    public int capacity() {
	return value.length;
    }

    public synchronized void ensureCapacity(int minimumCapacity) {
	if (minimumCapacity > value.length) {
	    expandCapacity(minimumCapacity);
	}
    }

    private void expandCapacity(int minimumCapacity) {
	int newCapacity = (value.length + 1) * 2;
        if (newCapacity < 0) {
            newCapacity = Integer.MAX_VALUE;
        } else if (minimumCapacity > newCapacity) {
	    newCapacity = minimumCapacity;
	}
	
	char newValue[] = new char[newCapacity];
	System.arraycopy(value, 0, newValue, 0, count);
	value = newValue;
    }

    public synchronized void setLength(int newLength) {
	if (newLength < 0) {
	    throw new StringIndexOutOfBoundsException(newLength);
	}
	
	if (newLength > value.length) {
	    expandCapacity(newLength);
	}

	if (count < newLength) {
	    for (; count < newLength; count++) {
		value[count] = '\0';
	    }
	} else {
            count = newLength;
        }
    }

    public synchronized char charAt(int index) {
	if ((index < 0) || (index >= count)) {
	    throw new StringIndexOutOfBoundsException(index);
	}
	return value[index];
    }

    public synchronized void getChars(int srcBegin, int srcEnd, char dst[], int dstBegin) {
	if (srcBegin < 0) {
	    throw new StringIndexOutOfBoundsException(srcBegin);
	}
	if ((srcEnd < 0) || (srcEnd > count)) {
	    throw new StringIndexOutOfBoundsException(srcEnd);
	}
        if (srcBegin > srcEnd) {
            throw new StringIndexOutOfBoundsException("srcBegin > srcEnd");
        }
	System.arraycopy(value, srcBegin, dst, dstBegin, srcEnd - srcBegin);
    }

    public synchronized void setCharAt(int index, char ch) {
	if ((index < 0) || (index >= count)) {
	    throw new StringIndexOutOfBoundsException(index);
	}
	value[index] = ch;
    }

    public synchronized SuperString append(Object obj) {
	return append(String.valueOf(obj));
    }

    public synchronized SuperString append(String str) {
	if (str == null) {
	    str = String.valueOf(str);
	}

	int len = str.length();
	int newcount = count + len;
	if (newcount > value.length)
	    expandCapacity(newcount);
	str.getChars(0, len, value, count);
	count = newcount;
	return this;
    }

    public synchronized SuperString append(char str[]) {
	int len = str.length;
	int newcount = count + len;
	if (newcount > value.length)
	    expandCapacity(newcount);
	System.arraycopy(str, 0, value, count, len);
	count = newcount;
	return this;
    }

    public synchronized SuperString append(SuperString str) {
	int len = str.count;
	int newcount = count + len;
	if (newcount > value.length)
	    expandCapacity(newcount);
	System.arraycopy(str.value, 0, value, count, len);
	count = newcount;
	return this;
    }

    public synchronized SuperString append(char str[], int offset, int len) {
        int newcount = count + len;
	if (newcount > value.length)
	    expandCapacity(newcount);
	System.arraycopy(str, offset, value, count, len);
	count = newcount;
	return this;
    }

    public SuperString append(boolean b) {
	return append(String.valueOf(b));
    }

    public synchronized SuperString append(char c) {
        int newcount = count + 1;
	if (newcount > value.length)
	    expandCapacity(newcount);
	value[count++] = c;
	return this;
    }

    public SuperString append(int i) {
	return append(String.valueOf(i));
    }

    public SuperString append(long l) {
	return append(String.valueOf(l));
    }

    public SuperString append(float f) {
	return append(String.valueOf(f));
    }

    public SuperString append(double d) {
	return append(String.valueOf(d));
    }

    public synchronized SuperString delete(int start, int end) {
	if (start < 0)
	    throw new StringIndexOutOfBoundsException(start);
	if (end > count)
	    end = count;
	if (start > end)
	    throw new StringIndexOutOfBoundsException();

        int len = end - start;
        if (len > 0) {
            System.arraycopy(value, start+len, value, start, count-end);
            count -= len;
        }
        return this;
    }

    public synchronized SuperString deleteCharAt(int index) {
        if ((index < 0) || (index >= count))
	    throw new StringIndexOutOfBoundsException();
	System.arraycopy(value, index+1, value, index, count-index-1);
	count--;
        return this;
    }

    public synchronized SuperString replace(int start, int end, String str) {
        if (start < 0)
	    throw new StringIndexOutOfBoundsException(start);
	if (end > count)
	    end = count;
	if (start > end)
	    throw new StringIndexOutOfBoundsException();

	int len = str.length();
	int newCount = count + len - (end - start);
	if (newCount > value.length)
	    expandCapacity(newCount);

        System.arraycopy(value, end, value, start + len, count - end);
        str.getChars(0, len, value, start);
	count = newCount;
        return this;
    }

    public String substring(int start) {
        return substring(start, count);
    }

    public synchronized String substring(int start, int end) {
	if (start < 0)
	    throw new StringIndexOutOfBoundsException(start);
	if (end > count)
	    throw new StringIndexOutOfBoundsException(end);
	if (start > end)
	    throw new StringIndexOutOfBoundsException(end - start);
        return new String(value, start, end - start);
    }

    public synchronized SuperString insert(int index, char str[], int offset,
                                                                   int len) {
        if ((index < 0) || (index > count))
	    throw new StringIndexOutOfBoundsException();
	if ((offset < 0) || (offset + len < 0) || (offset + len > str.length))
	    throw new StringIndexOutOfBoundsException(offset);
	if (len < 0)
	    throw new StringIndexOutOfBoundsException(len);
	int newCount = count + len;
	if (newCount > value.length)
	    expandCapacity(newCount);
	System.arraycopy(value, index, value, index + len, count - index);
	System.arraycopy(str, offset, value, index, len);
	count = newCount;
	return this;
    }

    public synchronized SuperString insert(int offset, Object obj) {
	return insert(offset, String.valueOf(obj));
    }

    public synchronized SuperString insert(int offset, String str) {
	if ((offset < 0) || (offset > count)) {
	    throw new StringIndexOutOfBoundsException();
	}

	if (str == null) {
	    str = String.valueOf(str);
	}
	int len = str.length();
	int newcount = count + len;
	if (newcount > value.length)
	    expandCapacity(newcount);
	System.arraycopy(value, offset, value, offset + len, count - offset);
	str.getChars(0, len, value, offset);
	count = newcount;
	return this;
    }

    public synchronized SuperString insert(int offset, char str[]) {
	return insert(offset, str, 0, str.length);
    }

    public SuperString insert(int offset, boolean b) {
	return insert(offset, String.valueOf(b));
    }

    public synchronized SuperString insert(int offset, char c) {
	int newcount = count + 1;
	if (newcount > value.length)
	    expandCapacity(newcount);
	System.arraycopy(value, offset, value, offset + 1, count - offset);
	value[offset] = c;
	count = newcount;
	return this;
    }

    public SuperString insert(int offset, int i) {
	return insert(offset, String.valueOf(i));
    }

    public SuperString insert(int offset, long l) {
	return insert(offset, String.valueOf(l));
    }

    public SuperString insert(int offset, float f) {
	return insert(offset, String.valueOf(f));
    }

    public SuperString insert(int offset, double d) {
	return insert(offset, String.valueOf(d));
    }

    public String toString() {
	return new String(value, 0, count);
    }

    /**
     * Added by CC, from String
     */
    public boolean regionMatches(boolean ignoreCase,
				 int to, String other, int po, int len) {
	if ((po < 0) || (to < 0) || (to > (long)count - len)
	    || (po > (long)other.length() - len)) {
	    return false;
	}
	while (len-- > 0) {
	    char c1 = value[to++];
	    char c2 = other.charAt(po++);
	    if (c1 == c2 || ignoreCase &&
		Character.toUpperCase(c1) == Character.toUpperCase(c2)) {
		// Will not work for Georgian alphabet!
	    } else
		return false;
	}
	return true;
    }

    public int indexOf(int ch, int fromIndex) {
	if (fromIndex < 0) {
	    fromIndex = 0;
	} else if (fromIndex >= count) {
	    return -1;
	}
	for (int i = fromIndex ; i < count ; i++) {
	    if (value[i] == ch) {
		return i;
	    }
	}
	return -1;
    }

    /**
     * Added by CC
     * Returns the index within this string of the first occurrence of the
     * specified substring, starting at the specified index. The search
     * is case-insensitive.
     */
    public int indexOfi(String pattern, int start) {
	int len = pattern.length();
	int stop = count - len + 1;
	for ( ; start < stop; start++) {
	    if (regionMatches(true, start, pattern, 0, len))
		return start;
	}
	return -1;
    }

    public Enumeration lineEnumeration() {
	return new Enumeration() {
		int idx = 0;

		public boolean hasMoreElements() {
		    return idx < count;
		}

		public Object nextElement() {
		    int lidx = idx;
		    idx = indexOf('\n', lidx);
		    if (idx == -1)
			idx = count + 1;
		    else
			idx++;
		    return supersub(lidx, idx - 1);
		}
	    };
    }

    public synchronized Reader reader() {
	if (value.length > count) {
	    char[] nv = new char[count];
	    System.arraycopy(value, 0, nv, 0, count);
	    value = nv;
	}
	return new CharArrayReader(value);
    }

    /** simple replacement of a pattern string. Faster than regexp. */
    public void findAndReplace(String pattern, String subs) {
	int start = 0;

	while ((start = indexOfi(pattern, start)) != -1)
	    replace(start, start + pattern.length(), subs);
    }

    /** Find and replace regular expression */
    public void findAndReplace(RE pattern, String subs) {
	REMatch match;
	int lm = 0;
	while ((match = pattern.getMatch(this, lm)) != null) {
	    String repl = match.substituteInto(subs);
	    replace(match.getStartIndex(), match.getEndIndex(), repl);
	    lm = match.getStartIndex() + repl.length();
	}
    }

    /**
     * Replace the results of the given match in the text
     * @param match the match
     * @param subs substitution string, may contain $n
     */
    public void replace(REMatch match, String subs) {
	String repl = match.substituteInto(subs);
	replace(match.getStartIndex(), match.getEndIndex(), repl);
    }
}
