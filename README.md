mitls-fstar (port of miTLS to F* 0.9)
=====================================

  * [Directory structure](#directory-structure)
  	* [Legacy, imported from mitls-f7](#legacy-imported-from-mitls-f7)
  * [Configuring Emacs and Atom F* modes](#configuring-emacs-and-atom-f-modes)

Directory structure
===================


- `3rdparty/`
	Legacy third-party libraries. We no longer depend on them, and they should be deleted at some point. Currently we link against libraries in https://github.com/FStarLang/3rdparty. New libraries should be added there or to a new 3rdparty git submodule, if needed.
	
- `src/`

  - `Makefile` `make all` is part of F* regression testing.
    Ideally, one should check that this target succeeds before pushing changes.
	 This builds the following targets:

    	- `mitls-lax`      for lax typechecking (legacy) files in `tls-lax`.
   		- `mitls-redux`    for lax typechecking selected files in `tls` and `tls-lax` (quite brittle).

 - `tls/` In-progress miTLS port. A few files have been ported and fully typecheck; others have been left almost untouched since Karthik ported them from mitls-f7. The `Makefile` here has two targets that are also part of regression testing:

  		- `mitls-ver` Full type checking of files that have been ported so far (listed in variable `VERIFY`)
  		- `mitls-ml`  OCaml code generation for files ported so far---generated files go to the `../tls-ml` directory
 
  - `tls-fs/` Legacy .fs (see also matching .fs7 files in mitls-f7)

  - `tls-lax/` is a shallow port from .fs to .fst that codegens to OCaml
  --- but does not compile yet because of missing native dependencies
  
  - `tls-ml/` OCaml code generated from tls and tls-lax files. Arguably, files here could be built and do not need to be in the repository.
 
   
  - `bug-reports/` Example files for Github issues should be placed here.

  - `fstar_proof/` an independent POPL'16 example, verifying the state machine in F* (out of date, JK is the expert; it could be moved to FStarLang/FStar).
    
  - `mipki/` Antoine's development on certificate management.
 
- `atom-fstar-build.json` Build configuration for using with F* interactive mode for Atom.


Legacy, imported from mitls-f7
---------

- `apps/` Sample apps built on top of miTLS --- not ported yet.

- `data/` Persistent data used by miTLS, e.g. a DH parameter cache --- not ported yet.

- `libs/` Our own libraries: CoreCrypto, Platform, and DHDB.
CoreCrypto and Platform had been moved to `FStarLang/FStar/contrib` and remaining files are deprecated, DHDB remains to be ported. 
  - `fst` F* specification
  - `fs` F# implementation
  - `ml` OCaml implementation

- `scripts/` Legacy scripts for distribution-management.

- `tests/` Legacy test suit

- `VS/` miTLS Visual Studio solution, for browsing/building the old F# files in `src/tls-fs` --- used to build as reference; currently broken. 

Configuring Emacs and Atom F* modes
===================================

The Makefile in `src/tls` has the following targets:

- `make json > ../atom-fstar-build.json` regenerates an atom-fstar-build.json file. To verify a module interactively, add `--verify_module <module>` in "options".
- `make <file.fst(i)>-ver` verifies an individual file.
- `make <file.fst(i)>-cfg` generates a `(*--build-config ... *)` that can be prepended to `<file.fst(i)>` for interactive verification or for verification from the command-line. 
- `make <file.fst(i)>-in` generates command-line arguments to use with the `--in` flag to verify `<file.fst(i)>`. 
This target can be used to pass appropriate arguments in `fstar-mode.el` using this snippet:

```elisp
(defun has-build-config ()
  "Checks if the buffer has a build-config."
  (save-excursion
    (goto-char (point-min))
    (looking-at-p (regexp-quote fstar-build-config-header))))

(defun my-fstar-compute-prover-args-using-make ()
  "Construct arguments to pass to F* by calling make."
  (when (not (has-build-config))
    (with-demoted-errors "Error when constructing arg string: %S"
      (let* ((fname (file-name-nondirectory buffer-file-name))
             (target (concat fname "-in"))
             (argstr (car (process-lines "make" "--quiet" target))))
        (split-string argstr)))))
  
(setq fstar-subp-prover-args #'my-fstar-compute-prover-args-using-make)
```

The above snippet will check for the presence of a  `(*--build-config ... *)` block, and only use make to generate the command-line arguments to pass to F* when there isn't one.

Error messages shown in the mini-buffer are sometimes truncated. It can be convenient to set the debug flag and open the `*Messages*` buffer in another window to see exactly what is going on. To make Emacs follow the end of the `*Messages*` buffer, use this snippet:

```elisp
(setq fstar-subp-debug t)

(defadvice message (after message-tail activate)
  "goto point max after a message"
  (with-current-buffer "*Messages*"
    (goto-char (point-max))
    (walk-windows
     (lambda (window)
       (if (string-equal (buffer-name (window-buffer window)) "*Messages*")
           (set-window-point window (point-max))))
     nil
     t)))
```
