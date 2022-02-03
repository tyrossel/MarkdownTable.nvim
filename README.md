# MarkdownTable.nvim

Edit and format your markdown tables with ease !

As with all line-based editors, modifying columns of tables can be difficult. This plugins provides some functions to help with that. Simply put your cursor on the table (=paragraph in vim), and call the appropriate function.

## Features

* Format : rewrite the table under the cursor following the [GitHub documentation](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/organizing-information-with-tables).
* Insert column
* Swap columns
* Delete columns
* Change text alignment: circle between left, right and center alignment to get the best result

## Installation

Using your favorite package manager:

```lua
# With packer.vim
use 'tyrossel/MarkdownTable.nvim'
```

## Usage

```lua
-- Prettify the whole table under the cursor:
:lua MdTableFormat<CR>

-- Delete the column under the cursor:
:lua MdTableColDelete<CR>

-- Insert a new column before the current column (where the cursor is):
:lua MdTableColInsert<CR>

-- Change the text alignment of the current column:
:lua MdTableColCircleAlign<CR>

-- Swap the current column with the one left to it:
:lua MdTableColSwap<CR>
```
