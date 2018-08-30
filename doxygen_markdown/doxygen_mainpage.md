\brief This markdown file includes the documentation entry page.

\mainpage Main page of the Example Project


# Markdown Syntax (with some Doxygen specific syntax)

Some first useless text without formatting ...

Special keywords can be used when they follow the `\` or `@` character
* mainpage, page
* subpage
* link , endlink
* section , subsection , subsubsection 
* brief
* paragraph
* ref
* ... and many others

\subpage ANOTHER_PAGE : This is a link to another page.

This is a reference to \ref MY_SECTION_LABEL as short version. \n
This is a reference to \ref MY_SECTION_LABEL "My 1. Section (alternative text)" as longer version.


___
## Line breaks and paragraphs

For Doxygen a line break requires a `\n` at the end of a line. \n
This is the next line after the line break.

And here starts a new paragraph which requires at least one empty line.

___
## Horizontal Lines
Can be generated with at least three `_` or `*` characters in a separate line.
Better do not use the minus (`-`) character because it is also used for headers.

***
\section EMPHASIS Phrase Emphasis 

Either *italic type* or **bold text** or even ***bold and italic*** is possible.

In this line there is **an *italic* and bold** mix.

<b> Bold text can also be nested \n
between `<b> </b>`
</b>

___
## Code Spans 

An inline code fragment like `fprintf()` is quite easy.

Also a code block is possible
```
disp('Test result');
error('Failed');
```

___
## Blockquote

> This a blockquote \n
> with two lines


___
## Lists

### Ordered/Numbered List

1. first
2. second

   A new paragraph within the list item
3. third


### Item List
Use characters * or + or - .
* first item: proceed first item
* second item:
  proceed second item
  + subitem a :
    continued line of subitem

    A new paragraph within the subitem
  + subitem b
    - subsubitem I
    - subsubitem II


___
## Links

A **direct URL link** works like this : <http://www.example.com>
```
<http://www.example.com>
```

An **inline link** like [Github](https://github.com/ "optional link title") is defined as follows
```
[Github](https://github.com/ "optional link title")
```


An invisible **reference link** is defined with
[Wikipedia]: https://www.wikipedia.org/ "optional link title"

```
[Wikipedia]: https://www.wikipedia.org/ (optional link title)
or
[Wikipedia]: https://www.wikipedia.org/ "optional link title"
```
and can be simply used in the text like this 
```
[Wikipedia]
or
[Wikipedia][]
or
[My Link Text][Wikipedia]
```
several times : [My Link Text][Wikipedia] - and again [Wikipedia][] and again [Wikipedia] .

