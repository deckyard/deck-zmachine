# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# zmachine - the object tree, attributes and properties.
# Spliced into zmachine.j via include - not a standalone module.

/**
 * Address of an object's entry.
 * @param m {Machine} the machine
 * @param o {int} the object number, from 1
 * @return {int} the address
 * @throws {Error} for object 0
 */
func objectAddress(m as Machine, o as int) {
    if ($o == 0) {
        failAt($m, "object 0 has no entry");
    }
    if ($m.version <= 3) {
        return $m.objects + 62 + 9 * ($o - 1);
    }
    return $m.objects + 126 + 14 * ($o - 1);
}

/**
 * Read a tree link of an object.
 * @param m {Machine} the machine
 * @param o {int} the object, 0 gives 0
 * @param which {int} 0 parent, 1 sibling, 2 child
 * @return {int} the linked object, 0 for none
 */
func link(m as Machine, o as int, which as int) {
    if ($o == 0) {
        return 0;
    }
    def a as int init objectAddress($m, $o);
    if ($m.version <= 3) {
        return $m.mem[$a + 4 + $which];
    }
    return word($m.mem, $a + 6 + 2 * $which);
}

/**
 * Write a tree link of an object.
 * @param m {Machine} the machine
 * @param o {int} the object
 * @param which {int} 0 parent, 1 sibling, 2 child
 * @param v {int} the linked object, 0 for none
 * @return {Machine} the machine with the link written
 */
func setLink(m as Machine, o as int, which as int, v as int) {
    def a as int init objectAddress($m, $o);
    if ($m.version <= 3) {
        $m = storeByte($m, $a + 4 + $which, $v);
        return $m;
    }
    $m = storeWord($m, $a + 6 + 2 * $which, $v);
    return $m;
}

/**
 * Test an attribute.
 * @param m {Machine} the machine
 * @param o {int} the object
 * @param attr {int} the attribute, 0 to 31 (47 from version 4)
 * @return {bool} true when it is set
 */
func hasAttr(m as Machine, o as int, attr as int) {
    if ($o == 0) {
        return false;
    }
    checkAttr($m, $attr);
    def a as int init objectAddress($m, $o) + $attr // 8;
    return ($m.mem[$a] >> (7 - $attr % 8)) & 1 == 1;
}

/**
 * Set or clear an attribute.
 * @param m {Machine} the machine
 * @param o {int} the object
 * @param attr {int} the attribute
 * @param on {bool} true to set it
 * @return {Machine} the machine with the attribute changed
 */
func setAttr(m as Machine, o as int, attr as int, on as bool) {
    if ($o == 0) {
        return $m;
    }
    checkAttr($m, $attr);
    def a as int init objectAddress($m, $o) + $attr // 8;
    def bit as int init 1 << (7 - $attr % 8);
    def b as int init $m.mem[$a];
    if ($on) {
        $b = $b | $bit;
    } else {
        $b = $b & (255 - $bit);
    }
    $m = storeByte($m, $a, $b);
    return $m;
}

/**
 * Reject an attribute number the version does not have.
 * @param m {Machine} the machine
 * @param attr {int} the attribute
 * @throws {Error} when it is out of range
 */
func checkAttr(m as Machine, attr as int) {
    def top as int init 48;
    if ($m.version <= 3) {
        $top = 32;
    }
    if ($attr < 0 or $attr >= $top) {
        failAt($m, "attribute " + convert.toString($attr) + " does not exist");
    }
}

/**
 * Take an object out of the tree, with its children.
 * @param m {Machine} the machine
 * @param o {int} the object
 * @return {Machine} the machine with the object detached
 */
func detach(m as Machine, o as int) {
    if ($o == 0) {
        return $m;
    }
    def parent as int init link($m, $o, 0);
    if ($parent == 0) {
        return $m;
    }
    def next as int init link($m, $o, 1);
    def first as int init link($m, $parent, 2);
    if ($first == $o) {
        $m = setLink($m, $parent, 2, $next);
    } else {
        def c as int init $first;
        while ($c != 0) {
            def sib as int init link($m, $c, 1);
            if ($sib == $o) {
                $m = setLink($m, $c, 1, $next);
                break;
            }
            $c = $sib;
        }
    }
    $m = setLink($m, $o, 0, 0);
    $m = setLink($m, $o, 1, 0);
    return $m;
}

/**
 * Make an object the first child of another.
 * @param m {Machine} the machine
 * @param o {int} the object
 * @param dest {int} the new parent
 * @return {Machine} the machine with the object moved
 */
func insertObject(m as Machine, o as int, dest as int) {
    if ($o == 0 or $dest == 0) {
        return $m;
    }
    $m = detach($m, $o);
    def first as int init link($m, $dest, 2);
    $m = setLink($m, $o, 1, $first);
    $m = setLink($m, $o, 0, $dest);
    $m = setLink($m, $dest, 2, $o);
    return $m;
}

/**
 * Address of an object's property table.
 * @param m {Machine} the machine
 * @param o {int} the object
 * @return {int} the address
 */
func propTable(m as Machine, o as int) {
    def a as int init objectAddress($m, $o);
    if ($m.version <= 3) {
        return word($m.mem, $a + 7);
    }
    return word($m.mem, $a + 12);
}

/**
 * An object's short name.
 * @param m {Machine} the machine
 * @param o {int} the object
 * @return {list of int} ZSCII codes
 */
func shortName(m as Machine, o as int) {
    if ($o == 0) {
        return [];
    }
    def t as int init propTable($m, $o);
    if ($m.mem[$t] == 0) {
        return [];
    }
    return decode($m, $t + 1, false);
}

/**
 * Address of the first property's size byte.
 * @param m {Machine} the machine
 * @param o {int} the object
 * @return {int} the address
 */
func firstProp(m as Machine, o as int) {
    def t as int init propTable($m, $o);
    return $t + 1 + 2 * $m.mem[$t];
}

/**
 * Number of the property whose size byte is at `a`; 0 ends the list.
 * @param m {Machine} the machine
 * @param a {int} address of the size byte
 * @return {int} the property number
 */
func propNumber(m as Machine, a as int) {
    if ($m.version <= 3) {
        return $m.mem[$a] & 31;
    }
    return $m.mem[$a] & 63;
}

/**
 * Bytes of size information in front of a property's data.
 * @param m {Machine} the machine
 * @param a {int} address of the first size byte
 * @return {int} 1 or 2
 */
func propHeader(m as Machine, a as int) {
    if ($m.version >= 4 and $m.mem[$a] >= 0x80) {
        return 2;
    }
    return 1;
}

/**
 * Length of a property's data from the address of that data
 * (`get_prop_len`).
 * @param m {Machine} the machine
 * @param data {int} the data address, 0 gives 0
 * @return {int} 1 to 64 bytes
 */
func propLength(m as Machine, data as int) {
    if ($data == 0) {
        return 0;
    }
    def b as int init $m.mem[$data - 1];
    if ($m.version <= 3) {
        return ($b >> 5) + 1;
    }
    if ($b >= 0x80) {
        def n as int init $b & 63;
        if ($n == 0) {
            return 64;
        }
        return $n;
    }
    if ($b & 0x40 != 0) {
        return 2;
    }
    return 1;
}

/**
 * Data address of an object's property.
 * @param m {Machine} the machine
 * @param o {int} the object
 * @param p {int} the property number
 * @return {int} the address, 0 when the object lacks the property
 */
func propAddress(m as Machine, o as int, p as int) {
    if ($o == 0) {
        return 0;
    }
    def a as int init firstProp($m, $o);
    while (true) {
        def n as int init propNumber($m, $a);
        if ($n == 0 or $n < $p) {
            return 0;
        }
        def data as int init $a + propHeader($m, $a);
        if ($n == $p) {
            return $data;
        }
        $a = $data + propLength($m, $data);
    }
    return 0;
}

/**
 * A property's value, or its default (`get_prop`).
 * @param m {Machine} the machine
 * @param o {int} the object
 * @param p {int} the property number
 * @return {int} the byte or word
 */
func getProp(m as Machine, o as int, p as int) {
    def data as int init propAddress($m, $o, $p);
    if ($data == 0) {
        return word($m.mem, $m.objects + 2 * ($p - 1));
    }
    if (propLength($m, $data) == 1) {
        return $m.mem[$data];
    }
    return word($m.mem, $data);
}

/**
 * Set a property's value (`put_prop`).
 * @param m {Machine} the machine
 * @param o {int} the object
 * @param p {int} the property number
 * @param v {int} the value
 * @return {Machine} the machine with the property written
 * @throws {Error} when the object lacks the property
 */
func putProp(m as Machine, o as int, p as int, v as int) {
    def data as int init propAddress($m, $o, $p);
    if ($data == 0) {
        failAt($m, "object " + convert.toString($o) + " has no property " + convert.toString($p));
    }
    if (propLength($m, $data) == 1) {
        $m = storeByte($m, $data, $v);
        return $m;
    }
    $m = storeWord($m, $data, $v);
    return $m;
}

/**
 * The property after `p` (`get_next_prop`); `p` 0 gives the first.
 * @param m {Machine} the machine
 * @param o {int} the object
 * @param p {int} the property number, 0 for the first
 * @return {int} the next property number, 0 after the last
 * @throws {Error} when the object lacks `p`
 */
func nextProp(m as Machine, o as int, p as int) {
    if ($o == 0) {
        return 0;
    }
    def a as int init firstProp($m, $o);
    if ($p != 0) {
        def data as int init propAddress($m, $o, $p);
        if ($data == 0) {
            failAt(
                $m,
                "object " + convert.toString($o) + " has no property " + convert.toString($p));
        }
        $a = $data + propLength($m, $data);
    }
    return propNumber($m, $a);
}
