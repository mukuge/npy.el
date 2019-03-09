;;; npy-buttercup-test.el --- Integration tests for npy.  -*- lexical-binding: t; -*-

;; Copyright (C) 2019  Cyriakus "Mukuge" Hill

;; Author: Cyriakus "Mukuge" Hill <cyriakus.h@gmail.com>
;; Keywords: tools

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Integration tests for npy with `buffercup'.

;;; Code:

(require 'buttercup)
(require 'seq)
(require 'f)
(require 's)
(require 'exec-path-from-shell)

(message "Running tests on Emacs %s" emacs-version)

;; (after-load 'exec-path-from-shell
;;   (dolist (var '("SSH_AUTH_SOCK" "SSH_AGENT_PID" "GPG_AGENT_INFO" "LANG" "LC_CTYPE"))
;;     (add-to-list 'exec-path-from-shell-variables var)))


(setq-default exec-path-from-shell-arguments nil)
(exec-path-from-shell-initialize)

(defvar npy-test/test-path
  (directory-file-name (file-name-directory load-file-name))
  "Path to tests directory.")

(defvar npy-test/root-path
  (directory-file-name (f-dirname (file-name-directory npy-test/test-path)))
  "Path to root directory.")

(defvar npy-test/playground-path
  "/tmp/npy-playground/"
  "Path to the playground for test.")

(defvar npy-test/python-wait
  1
  "Sleep for duration after inputting somethng to a Python interpreter.")

(load (expand-file-name "npy" npy-test/root-path) 'noerror 'nomessage)
(npy-mode 1)
;;(npy-initialize)

(setq npy-test/venv-root-for-project1 (s-chomp (shell-command-to-string "(cd /tmp/npy-playground/project1/ && pipenv --venv)")))
(setq npy-test/venv-root-for-project2 (s-chomp (shell-command-to-string "(cd /tmp/npy-playground/project2/ && pipenv --venv)")))


(describe "dispatch feature: dispatching code chunnks from
python-mode buffers to virtualenv-dedicated inferior python
buffers"
  (describe "when there are two virtualenv-dedicated inferior
  python buffers: one is spawned on 'project1/buz.py' and the
  other is spawned on 'project2/foo.py'"
    (it "dispatches code chunks sent from two python-mode buffers
    into respective infeior buffers"
      (with-files-in-playground (("project1/buz.py" . "VAR = \"from buz.py\"")
                                 ("project2/foo.py" . "VAR = \"from foo.py\""))
        (with-file-buffers ("project1/buz.py" "project2/foo.py")
          (with-current-buffer "buz.py"
            (npy-run-python))
          (with-current-buffer "foo.py"
            (npy-run-python))
          (npy-helper-wait)
          (let ((python-inf-buf-1 (get-buffer "*Python[Pipenv:project1]*"))
                (python-inf-buf-2 (get-buffer "*Python[Pipenv:project2]*")))
            (with-current-buffer "buz.py"
              (python-shell-send-buffer))
            (with-current-buffer "foo.py"
              (python-shell-send-buffer))
            (should-response-match python-inf-buf-1
              "print(VAR)\n" "from buz.py")
            (should-response-match python-inf-buf-2
              "print(VAR)\n" "from foo.py")
            (npy-helper-kill-python-inferior-buffers python-inf-buf-1 python-inf-buf-2))))))
  (describe "when there are two virtualenv-dedicated inferior
  python buffers: inf-buf-1 is spawned on 'project1/buz.py' and
  inf-buf-2 is spawned on 'project2/foo.py'"
    (it "dispatches code chunks from 'project1/buz.py' into
    inf-buf-1, 'project1/foo.py' into inf-buf-1, and from
    'project2/bar.py' into inf-buf-2"
      (with-files-in-playground (("project1/buz.py" . "VAR = \"from buz.py\"")
                                 ("project1/foo.py" . "VAR = \"from foo.py\"")
                                 ("project2/bar.py" . "VAR2 = \"from bar.py\""))
        (with-file-buffers ("project1/buz.py" "project1/foo.py" "project2/bar.py")
          (with-current-buffer "buz.py"
            (npy-run-python))
          ;; (with-current-buffer "foo.py"
          ;;   (npy-run-python))
          (with-current-buffer "bar.py"
            (npy-run-python))
          (npy-helper-wait)
          (let ((python-inf-buf-1 (get-buffer "*Python[Pipenv:project1]*"))
                (python-inf-buf-2 (get-buffer "*Python[Pipenv:project2]*")))
            (with-current-buffer "foo.py"
              (python-shell-send-buffer))
            (should-response-match python-inf-buf-1
              "print(VAR)\n" "from foo.py")
            (with-current-buffer "bar.py"
              (python-shell-send-buffer))
            (should-response-match python-inf-buf-2
              "print(VAR2)\n" "from bar.py")
            (npy-helper-kill-python-inferior-buffers python-inf-buf-1 python-inf-buf-2))))))
  (describe "when there are two virtualenv-buffer dedicated
  buffers: inf-buf-1 is spawned on 'project1/buz.py' and
  inf-buf-2 is spawned on 'project1/foo.py'"
    (it "dispatches code chunks sent from 'project1/buz.py' into
    inf-buf-1, and from 'project1/foo.py' into inf-buf-2"
      (with-files-in-playground (("project1/buz.py" . "VAR = \"from buz.py\"")
                                 ("project1/foo.py" . "VAR = \"from foo.py\""))
        (with-file-buffers ("project1/buz.py" "project1/foo.py")
          (with-current-buffer "buz.py"
            (npy-run-python t))
          (with-current-buffer "foo.py"
            (npy-run-python t))
          (npy-helper-wait)
          (let ((python-inf-buf-1 (get-buffer "*Python[Pipenv:project1;b:buz.py]*"))
                (python-inf-buf-2 (get-buffer "*Python[Pipenv:project1;b:foo.py]*")))
            (with-current-buffer "buz.py"
              (python-shell-send-buffer))
            (with-current-buffer "foo.py"
              (python-shell-send-buffer))
            (should-response-match python-inf-buf-1
              "print(VAR)\n" "from buz.py")
            (should-response-match python-inf-buf-2
              "print(VAR)\n" "from foo.py")
            (npy-helper-kill-python-inferior-buffers python-inf-buf-1 python-inf-buf-2)))))))

(provide 'npy-buttercup-test)
;;; npy-buttercup-test.el ends here
