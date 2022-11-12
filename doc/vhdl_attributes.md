# VHDL Attributes (VHDL 2008 and earlier)

A compact overview with some examples.

## Enumerator
type C is (blue, yellow, red, green, black, orange, brown, white);

| Usage          | Result |
|:---------------|:-------|
| C'right        | white  |
| C'left         | blue   |
| C'right        | white  |
| C'left         | blue   |
| C'high         | white  |
| C'low          | blue   |
| C'pos(blue)    | 0      |
| C'pos(white)   | 7      |
| C'val(4)       | black  |
| C'leftof(red)  | yellow |
| C'rightof(red) | green  |
| C'pred(orange) | black  |
| C'succ(orange) | brown  |

## Constrained Array
type mybasetype is array(integer range <>, integer range <>) of std_logic_vector;

subtype mysubtype is mybasetype(2 downto -1 , -5 to 3)(7 downto 0);

variable A : mysubtype;

| Usage                   | Return  | Result                      |
|:------------------------|:--------|:----------------------------|
| A'subtype               | type    | mysubtype                   |
| A'subtype'base          | type    | mybasetype                  |
| A'element               | type    | std_logic_vector(7 downto 0)|
| A'range(1)              | range   | 2 downto -1                 |
| A'range(2)              | range   | -5 to 3                     |
| A'element'range         | range   | 7 downto 0                  |
| A'reverse_range(1)      | range   | -1 to 2                     |
| A'reverse_range(2)      | range   | 3 downto -5                 |
| A'element'reverse_range | range   | 0 to 7                      |
| A'length(1)             | integer | 4                           |
| A'length(2)             | integer | 9                           |
| A'element'length        | integer | 8                           |
| A'left(1)               | integer | 2                           |
| A'left(2)               | integer | -5                          |
| A'element'left          | integer | 7                           |
| A'right(1)              | integer | -1                          |
| A'right(2)              | integer | 3                           |
| A'element'right         | integer | 0                           |
| A'high(1)               | integer | 2                           |
| A'high(2)               | integer | 3                           |
| A'element'high          | integer | 7                           |
| A'low(1)                | integer | -1                          |
| A'low(2)                | integer | -5                          |
| A'element'low           | integer | 0                           |
| A'ascending(1)          | boolean | false                       |
| A'ascending(2)          | boolean | true                        |
| A'element'ascending     | boolean | false                       |

The 'subtype and 'element attribute can be useful for dependent declarations.
* variable aux1 : A'subtype;
* type t1 is array(natural range <>) of A'element;

The 'range attribute can be useful for loops or to constrain other related objects.
* for i in A'element'range loop ... end loop;
* for i in A'range(1) generate ... end generate;
* variable B : std_logic_vector(A'element'reverse_range);

## Base Type

The 'base attribute is applied to types and returns the base type of a subtype.

| Usage                   | Result                      |
|:------------------------|:----------------------------|
| natural'base            | integer                     |
| unsigned'base           | unresolved_unsigned         |
| mysubtype'base          | mybasetype                  |
| mysubtype'element'base  | std_ulogic_vector           |

## Integer and Boolean

variable I : integer range 25 downto -13 := 22;

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

## Entities

Example: Within architecture TB of entity TOP we have an instance I1 of entity E with architecture RTL. 

| Usage           | Result               | Description                                                 |
|:----------------|:---------------------|:------------------------------------------------------------|
| E'simple_name   | "E"                  | string with just the name of entity E                       |
| E'path_name     | ":TOP:I1"            | string with hierarchy of entity E (relative to design root) |
| E'instance_name | ":TOP(TB):I1@E(RTL)" | string with design hierarchy including entity E             |

The '*_name attributes can be useful in connection with asserts and reporting.

---
Fixitfetish@github.com
