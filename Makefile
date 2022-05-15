all: test check

install_plenary:
	if [ ! -d ~/.local/share/nvim/site/pack/vendor/opt/plenary.nvim ]; \
	then \
		git clone --depth 1 https://github.com/nvim-lua/plenary.nvim \
		~/.local/share/nvim/site/pack/vendor/opt/plenary.nvim; \
	fi

test: install_plenary
	nvim --headless --noplugin -u tests/minimal.vim -R \
		-c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal.vim'}"

check:
	stylua --color always --check .
