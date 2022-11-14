# VHDL Attributes (VHDL 2008 and earlier)

A compact overview with some examples.

## Attributes on Arrays
```
subtype byte is bit_vector(7 downto 0);
type byte_matrix is array(integer range <>, integer range <>) of byte; -- 2-dim matrix of bytes
subtype my_matrix is byte_matrix(2 downto -1 , -5 to 3);
signal M : my_matrix;
```

| Usage                   | Return  | Result                      |
|:------------------------|:--------|:----------------------------|
| M'subtype               | type    | my_matrix                   |
| M'subtype'base          | type    | byte_matrix (unconstrained) |
| M'subtype'element       | type    | byte                        |
| M'element               | type    | byte                        |
| M'element'base          | type    | bit_vector (unconstrained)  |
| M'element'element       | type    | bit                         |
| M'range(1)              | range   | 2 downto -1                 |
| M'range(2)              | range   | -5 to 3                     |
| M'element'range         | range   | 7 downto 0                  |
| M'reverse_range(1)      | range   | -1 to 2                     |
| M'reverse_range(2)      | range   | 3 downto -5                 |
| M'element'reverse_range | range   | 0 to 7                      |
| M'length(1)             | integer | 4                           |
| M'length(2)             | integer | 9                           |
| M'element'length        | integer | 8                           |
| M'left(1)               | integer | 2                           |
| M'left(2)               | integer | -5                          |
| M'element'left          | integer | 7                           |
| M'right(1)              | integer | -1                          |
| M'right(2)              | integer | 3                           |
| M'element'right         | integer | 0                           |
| M'high(1)               | integer | 2                           |
| M'high(2)               | integer | 3                           |
| M'element'high          | integer | 7                           |
| M'low(1)                | integer | -1                          |
| M'low(2)                | integer | -5                          |
| M'element'low           | integer | 0                           |
| M'ascending(1)          | boolean | false                       |
| M'ascending(2)          | boolean | true                        |
| M'element'ascending     | boolean | false                       |

The 'subtype , 'element and 'base attributes can be useful for dependent declarations.
* signal aux1 : M'subtype;
* signal word : M'element'base(15 downto 0);
* signal M2 : M'subtype'base(0 to 3, 0 to 7);
* type byte_vector is array(natural range <>) of M'element;

The 'range attribute can be useful for loops or to constrain other related objects.
* for i in M'element'range loop ... end loop;
* for i in M'range(1) generate ... end generate;
* signal B : M'element'base(M'element'reverse_range);

The 'high , 'low , 'left and 'right attributes are useful when the range is flexible.
* sr <= sr(sr'high-1 downto sr'low) & sr(sr'high); -- shift register

## Attributes on Types

The 'base attribute is applied to types and returns the base type of a subtype.

| Usage                   | Return  |Result                      |
|:------------------------|:--------|:---------------------------|
| natural'base            | type    | integer                    |
| unsigned'base           | type    | unresolved_unsigned        |
| std_logic_vector'base   | type    | std_ulogic_vector          |
| unsigned'element        | type    | std_logic                  |

```
type color is (blue, yellow, red, green, black, orange, brown, white); -- enumeration type
```

| Usage              | Result | Description                         |
|:-------------------|:-------|:------------------------------------|
| color'right        | white  | rightmost in list                   |
| color'left         | blue   | leftmost in list                    |
| color'high         | white  | at highest position                 |
| color'low          | blue   | at lowest position                  |
| color'pos(blue)    | 0      | position of list element            |
| color'pos(white)   | 7      | position of list element            |
| color'val(4)       | black  | Value at position X                 |
| color'leftof(red)  | yellow | left of another list element        |
| color'rightof(red) | green  | right of another list element       |
| color'pred(orange) | black  | predecessor of another list element |
| color'succ(orange) | brown  | successor of another list element   |
| color'ascending    | true   | check if range is TO direction      |

## Integer and Boolean

```
signal I : integer range 25 downto -13 := 22;
```

| Usage                   | Result                      |
|:------------------------|:----------------------------|
| positive'low            | 1                           |
| integer'high            | 2147483647                  |
| integer'image(I)        | "22"                        |
| I'subtype'high          | 25                          |
| I'subtype'right         | -13                         |
| I'subtype'ascending     | false                       |
| integer'value("1234")   | 1234                        |
| boolean'image(true)     | "true"                      |
| boolean'value("FALSE")  | false                       |

The 'image and 'value attribute can be useful for test benches and simulation.

## Attributes on Entities

Example: Within architecture TB of entity TOP we have an instance I1 of entity E with architecture RTL. 

| Usage           | Result               | Description                                                 |
|:----------------|:---------------------|:------------------------------------------------------------|
| E'simple_name   | "E"                  | string with just the name of entity E                       |
| E'path_name     | ":TOP:I1"            | string with hierarchy of entity E (relative to design root) |
| E'instance_name | ":TOP(TB):I1@E(RTL)" | string with design hierarchy including entity E             |

The '*_name attributes can be useful in connection with asserts and reporting.

## Attributes on Signals

TODO

---
<https://github.com/Fixitfetish>
