{ username, standalone ? false }: { config, pkgs, ... }:

let
homeConfUpper = if standalone then config else config.home-manager.users."${username}";
homeConf = {
  home = {
    inherit username;
    stateVersion = "24.05";
    packages = with pkgs; [ ripgrep ];
    file.".gnupg/gpg-agent.conf".text = ''
      max-cache-ttl 18000
      default-cache-ttl 18000
      enable-ssh-support
    '';
    sessionPath = [
      "${homeConfUpper.home.homeDirectory}/.local/bin" # XXX: express with XDG?
    ];
  };

  programs = {
    vim = {
      enable = true;
      defaultEditor = true;
      plugins = with pkgs.vimPlugins; [
        vim-airline
        vim-clang-format
        vim-fugitive
        vim-haskell-indent
        vim-husk
        vim-markdown
        vim-nix
        vim-ripgrep
        vim-surround
        vim-tbone
      ];
      extraConfig = ''
        inoremap jk <ESC>
        let mapleader = "\<Space>"

        filetype plugin indent on
        syntax on
        set encoding=utf-8
        set nocompatible
        set hlsearch
        set incsearch
        set nu rnu
        set bg=dark

        set tabstop=4
        set shiftwidth=4
        set softtabstop=4
        set expandtab

        let g:airline_powerline_fonts = 1

        " encoding
        if has("multi_byte")
            if &termencoding == ""
                let &termencoding = &encoding
            endif
            set encoding=utf-8
            setglobal fileencoding=utf-8
            " setglobal bomb
            set fileencodings=ucs-bom,utf-8,latin1
        endif

        " haskellmode config
        au BufEnter *.hs compiler ghc
        let g:haddock_browser="/usr/bin/firefox"
        let g:haddock_browser_callformat = "'%s file://%s '.printf(&shellredir,'/dev/null').' &'"

        " prefer LaTeX flavor of TeX
        let g:tex_flavor = "latex"
        " `ysiwc` for inserting LaTeX command
        let g:surround_{char2nr('c')} = "\\\1command\1{\r}"

        " ClangFormat
        let g:clang_format#code_style = "llvm"
        let g:clang_format#detect_style_file = 1
        let g:clang_format#auto_format = 1
        let g:clang_format#auto_format_on_insert_leave = 1
        if !executable("clang-format")
            " use clang-format from SCL
            let g:clang_format#command = "/opt/rh/llvm-toolset-7/root/usr/bin/clang-format"
        endif

        au FileType c,cpp,objc setlocal tabstop=2 shiftwidth=2 softtabstop=2
        au FileType c,cpp,objc nnoremap <buffer><Leader>C :ClangFormatAutoToggle<CR>
        au FileType c,cpp,objc nnoremap <buffer><Leader>cf :<C-u>ClangFormat<CR>
        au FileType c,cpp,objc vnoremap <buffer><Leader>cf :ClangFormat<CR>

        " Removes trailing spaces
        function! TrimWhiteSpace()
            " Only strip if the b:noStripWhitespace variable isn't set
            if exists('b:noStripWhitespace')
                return
            endif
            %s/\s*$//
            \'\'
        endfunction

        " Control characters expansion
        set list listchars=tab:»-,trail:.,eol:↲,extends:»,precedes:«,nbsp:%
        au FileType diff let b:noStripWhitespace=1
        au FileWritePre * call TrimWhiteSpace()
        au FileAppendPre * call TrimWhiteSpace()
        au FilterWritePre * call TrimWhiteSpace()
        au BufWritePre * call TrimWhiteSpace()

        " Highlighting-related
        function! SynStack()
            if !exists("*synstack")
                return
            endif
            echo map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")')
        endfunc
        hi NonText      ctermbg=NONE ctermfg=DarkGrey guibg=NONE guifg=NONE
        hi SpecialKey   ctermbg=NONE ctermfg=DarkGrey guibg=NONE guifg=NONE

        " Cursorline control
        set cursorline
        hi CursorLine cterm=NONE ctermbg=233 ctermfg=NONE guibg=NONE guifg=NONE
        nnoremap H :set cursorline!<CR>

        " Fix cursorline TODO conflict:
        " https://vi.stackexchange.com/questions/3288/override-cursorline-background-color-by-syntax-highlighting
        hi Todo         ctermbg=Black ctermfg=Yellow cterm=reverse

        " Tabs
        nnoremap t. :tabedit %<CR>
        nnoremap tc :tabclose<CR>
        nnoremap tn :tabnext<CR>
        nnoremap tp :tabprevious<CR>

        " Markdown
        let g:markdown_fenced_languages = ['vim', 'bash']

        " vim-tbone remaps
        nnoremap <leader>y :Tyank<CR>

        " global search with vim-ripgrep
        let g:rg_derive_root = 1
        nnoremap <leader>* :Rg -w <cword><CR>

        set switchbuf+=usetab,newtab

        " fold with syntax by default
        set foldmethod=syntax
        set nofoldenable
      '';
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    gpg = {
      enable = true;
      settings = {
        auto-key-retrieve = true;
        no-emit-version = true;
        default-key = "EEE87C527B2D913A8CBAD48C725079137D8A5B65";
        encrypt-to = "i@jsteward.moe";
      };
    };

    zsh = {
      enable = true;
      syntaxHighlighting.enable = true;
      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "gpg-agent" ];
        theme = "candy";
      };

      shellAliases = {
        ls = "ls -G --color=auto";
      };

      initExtra = ''
          # TMUX auto attach
          if which tmux >/dev/null 2>&1; then
            case $- in
              *i*) test -z "$TMUX" && (tmux attach || tmux new-session)
            esac
          fi

          # iTerm2 integration
          test -e "$HOME/.iterm2_shell_integration.zsh" && source "$HOME/.iterm2_shell_integration.zsh"
      '';
    };

    autojump.enable = true;
    dircolors = {
      enable = true;
      enableZshIntegration = true;
    };
    bat.enable = true;
    home-manager.enable = true;
  };
}; in if standalone then homeConf else {
  home-manager.useUserPackages = true;
  home-manager.useGlobalPkgs = true;
  home-manager.users."${username}" = homeConf;
}
