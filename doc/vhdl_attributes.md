# VHDL Attributes and Examples (VHDL 2008 and earlier)

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

| Usage                   | Result                      |
|:------------------------|:----------------------------|
| A'subtype               | mysubtype                   |
| A'subtype'base          | mybasetype                  |
| A'element               | std_logic_vector(7 downto 0)|
| A'length(1)             | 4                           |
| A'length(2)             | 9                           |
| A'element'length        | 8                           |
| A'range(1)              | 2 downto -1                 |
| A'range(2)              | -5 to 3                     |
| A'element'range         | 7 downto 0                  |
| A'reverse_range(1)      | -1 to 2                     |
| A'reverse_range(2)      | 3 downto -5                 |
| A'element'reverse_range | 0 to 7                      |
| A'left(1)               | 2                           |
| A'left(2)               | -5                          |
| A'element'left          | 7                           |
| A'right(1)              | -1                          |
| A'right(2)              | 3                           |
| A'element'right         | 0                           |
| A'high(1)               | 2                           |
| A'high(2)               | 3                           |
| A'element'high          | 7                           |
| A'low(1)                | -1                          |
| A'low(2)                | -5                          |
| A'element'low           | 0                           |
| A'ascending(1)          | false                       |
| A'ascending(2)          | true                        |
| A'element'ascending     | false                       |

## Base Type

Returns the base type of a subtype.

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

## Entities

Example: Within architecture TB of entity TOP we have an instance I1 of entity E with architecture RTL. 

| Usage           | Result               | Description                                                 |
|:----------------|:---------------------|:------------------------------------------------------------|
| E'simple_name   | "E"                  | string with just the name of entity E                       |
| E'path_name     | ":TOP:I1"            | string with hierarchy of entity E (relative to design root) |
| E'instance_name | ":TOP(TB):I1@E(RTL)" | string with design hierarchy including entity E             |
