;;; -*- coding: utf-8-unix -*-
;;;
;;;Part of: Wak Infix
;;;Contents: implementation of the INFIX syntax
;;;Date: Tue May 18, 2010
;;;
;;;Abstract
;;;
;;;	The  parser driver  is from  the Lalr-scm  package  by Dominique
;;;	Boucher; the parser table is also generated using Lalr-scm.
;;;
;;;Copyright (c) 2010 Marco Maggi <marco.maggi-ipsu@poste.it>
;;;Copyright (c) 2005-2008 Dominique Boucher
;;;
;;;This program is free software:  you can redistribute it and/or modify
;;;it under the terms of the  GNU General Public License as published by
;;;the Free Software Foundation, either version 3 of the License, or (at
;;;your option) any later version.
;;;
;;;This program is  distributed in the hope that it  will be useful, but
;;;WITHOUT  ANY   WARRANTY;  without   even  the  implied   warranty  of
;;;MERCHANTABILITY  or FITNESS FOR  A PARTICULAR  PURPOSE.  See  the GNU
;;;General Public License for more details.
;;;
;;;You should  have received  a copy of  the GNU General  Public License
;;;along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;;


(library (wak-infix)
  (export infix)
  (import (rnrs))


(define-syntax infix
  (let ()
    (define-record-type <lexical-token>
      (fields (immutable category)
	      (immutable location)
	      (immutable value)
	      (immutable length))
      (nongenerative wak:infix:<lexical-token>))

    ;;Constant tokens representing the recognised operators.
    (define $add	(make-<lexical-token> 'ADD #f #'+ 0))
    (define $sub	(make-<lexical-token> 'SUB #f #'- 0))
    (define $mul	(make-<lexical-token> 'MUL #f #'* 0))
    (define $div	(make-<lexical-token> 'DIV #f #'/ 0))
    (define $mod	(make-<lexical-token> 'MOD #f #'mod 0))
    (define $expt	(make-<lexical-token> 'EXPT #f #'expt 0))
    (define $div0	(make-<lexical-token> 'DIV0 #f #'div 0))
    (define $lt		(make-<lexical-token> 'LT #f #'< 0))
    (define $gt		(make-<lexical-token> 'GT #f #'> 0))
    (define $le		(make-<lexical-token> 'LE #f #'<= 0))
    (define $ge		(make-<lexical-token> 'GE #f #'>= 0))
    (define $eq		(make-<lexical-token> 'EQ #f #'= 0))
    ;;Here we  use the  #'if syntax  object as semantic  value: it  is a
    ;;trick to avoid  insertion of a raw value: the  parser will take it
    ;;and use it as the IF in the output form.
    (define $question	(make-<lexical-token> 'QUESTION-ID #f #'if 0))
    (define $colon	(make-<lexical-token> 'COLON-ID #f #': 0))

    ;;Special constant  tokens.  Notice that  the left and  right parens
    ;;tokens  are wrapped  in  a list  because  below they  are used  as
    ;;arguments to APPEND.
    (define $eoi		(make-<lexical-token> '*eoi* #f (eof-object) 0))
    (define $left-paren		(make-<lexical-token> 'LPAREN #f #\( 0))
    (define $right-paren	(make-<lexical-token> 'RPAREN #f #\) 0))

    (define-syntax memv
      (syntax-rules ()
	((_ ?atom ?stx)
	 (free-identifier=? ?atom ?stx))
	((_ ?atom ?stx ...)
	 (or (free-identifier=? ?atom ?stx) ...))))

    (define-syntax case
      (syntax-rules (else)
	((_ ?atom ((?s ...) ?e ...) ... (else ?b ...))
	 (cond ((memv ?atom #'?s ...) ?e ...) ... (else ?b ...)))))

    (define-syntax prefix
      ;;Used to mark prefix-notation expressions in SYNTAX->LIST.
      ;;
      (identifier-syntax #f))

    (define-syntax drop/stx
      (syntax-rules ()
	((_ ?ell ?k)
	 (let loop ((ell ?ell)
		    (k   ?k))
	   (if (zero? k)
	       ell
	     (loop (cdr ell) (- k 1)))))))

    (define-syntax define-inline
      (syntax-rules ()
	((_ (?name ?arg ...) ?form0 ?form ...)
	 (define-syntax ?name
	   (syntax-rules ()
	     ((_ ?arg ...)
	      (begin ?form0 ?form ...)))))))

    (define (syntax->list stx)
      (syntax-case stx ()
	((?begin . ?body)
	 (and (identifier? #'?begin) (free-identifier=? #'begin #'?begin))
	 (cons #'prefix #'?body))
	(()		'())
	((?car . ?cdr)	(cons (syntax->list #'?car) (syntax->list #'?cdr)))
	(?atom		(identifier? #'?atom)	#'?atom)
	(?atom		(syntax->datum #'?atom))))

    (define (stx-list->reversed-tokens sexp reversed-tokens)
      ;;Convert a list of syntax objects to the reversed list of tokens.
      ;;This  is a  recursive function:  it recurses  to  process nested
      ;;lists in the  input SEXP; for this reason  we cannot reverse the
      ;;tokens here, we have to let the caller reverse it.
      ;;
      (if (null? sexp)
	  reversed-tokens
	(let ((atom (car sexp)))
	  (cond ((identifier? atom)
		 (stx-list->reversed-tokens
		  (cdr sexp)
		  (cons (case atom
			  ((+)			$add)
			  ((-)			$sub)
			  ((*)			$mul)
			  ((/)			$div)
			  ((% mod)		$mod)
			  ((^ expt)		$expt)
			  ((// div)		$div0)
			  ((<)			$lt)
			  ((>)			$gt)
			  ((<=)			$le)
			  ((>=)			$ge)
			  ((=)			$eq)
			  ((?)			$question)
			  ((:)			$colon)
			  (else
			   (make-<lexical-token> 'ID #f atom 0)))
			reversed-tokens)))
		((pair? atom)
		 (if (and (identifier? (car atom))
			  (free-identifier=? #'prefix (car atom)))
		     (stx-list->reversed-tokens
		      (cdr sexp)
		      (cons (make-<lexical-token> 'NUM #f (cons #'begin (cdr atom)) 0)
			    reversed-tokens))
		   ;;Parentheses  in reverse  order  because the  TOKENS
		   ;;will be reversed!!!
		   (stx-list->reversed-tokens
		    (cdr sexp)
		    (cons $right-paren
			  (stx-list->reversed-tokens atom (cons $left-paren reversed-tokens))))))
		(else
		 ;;Everything else  is just put there as  "NUM", that is
		 ;;as operand.
		 (stx-list->reversed-tokens
		  (cdr sexp)
		  (cons (make-<lexical-token> 'NUM #f atom 0)
			reversed-tokens)))))))


    (define (lr-driver action-table goto-table reduction-table)
      (define (parser-instance true-lexer error-handler yycustom)
	(let ((stack-values		'(#f))
	      (stack-states		'(0))
	      (reuse-last-token	#f))

	  (define (main lookahead)
	    (let ((category (<lexical-token>-category lookahead)))
	      (if (eq? '*lexer-error* category)
		  (main (attempt-error-recovery lookahead))
		(let ((action (select-action category (current-state))))
		  (cond ((eq? action 'accept) ;success, end of parse
			 (cadr stack-values)) ;return the value to the caller

			((eq? action '*error*) ;syntax error in input
			 (if (eq? category '*eoi*)
			     (error-handler "unexpected end of input" lookahead)
			   (main (attempt-error-recovery lookahead))))

			((<= 0 action) ;shift (= push) token on the stack
			 (stack-push! action (<lexical-token>-value lookahead))
			 (main (if (eq? category '*eoi*)
				   lookahead
				 (begin
				   (reduce-using-default-actions)
				   (lexer)))))

			(else ;reduce using the rule at index "(- ACTION)"
			 (reduce (- action))
			 (main lookahead)))))))

	  (define lexer
	    (let ((last-token #f))
	      (lambda ()
		(if reuse-last-token
		    (set! reuse-last-token #f)
		  (begin
		    (set! last-token (true-lexer))
		    (unless (<lexical-token>? last-token)
		      (error-handler "expected lexical token from lexer" last-token)
		      (true-lexer))))
		last-token)))

	  (define (yypushback)
	    (set! reuse-last-token #t))

	  (define (select-action terminal-symbol state-index)
	    (let* ((action-alist (vector-ref action-table state-index))
		   (pair         (assq terminal-symbol action-alist)))
	      (if pair (cdr pair) (cdar action-alist))))

	  (define (reduce reduction-table-index)
	    (define (%main)
	      (apply (vector-ref reduction-table reduction-table-index)
		     reduce-pop-and-push yypushback yycustom stack-states stack-values))

	    (define (reduce-pop-and-push used-values goto-keyword semantic-clause-result
					 yy-stack-states yy-stack-values)
	      (let* ((yy-stack-states (drop/stx yy-stack-states used-values))
		     (new-state-index (cdr (assq goto-keyword
						 (vector-ref goto-table (car yy-stack-states))))))
		;;This is NOT a call to STACK-PUSH!
		(set! stack-states (cons new-state-index        yy-stack-states))
		(set! stack-values (cons semantic-clause-result yy-stack-values))))

	    (%main))

	  (define (reduce-using-default-actions)
	    (let ((actions-alist (vector-ref action-table (current-state))))
	      (when (= 1 (length actions-alist))
		(let ((default-action (cdar actions-alist)))
		  (when (< default-action 0)
		    (reduce (- default-action))
		    (reduce-using-default-actions))))))

	  (define (attempt-error-recovery lookahead)

	    (define (%main)
	      (error-handler "syntax error, unexpected token" lookahead)
	      (let ((token (synchronise-parser/rewind-stack)))
		;;If recovery succeeds: TOKEN  is set to the next lookahead.
		;;If recovery fails: TOKEN is set to end--of--input.
		(unless (eq? '*eoi* (<lexical-token>-category token))
		  (reduce-using-default-actions))
		token))

	    (define (synchronise-parser/rewind-stack)
	      (if (null? stack-values)
		  (begin ;recovery failed, simulate end-of-input
		    (stack-push! 0 #f) ;restore start stacks state
		    (make-<lexical-token> '*eoi*
					  (<lexical-token>-location lookahead)
					  (eof-object)
					  #f))
		(let* ((entry (state-entry-with-error-action (current-state))))
		  (if entry
		      (synchronise-lexer/skip-tokens (cdr entry))
		    (begin
		      (stack-pop!)
		      (synchronise-parser/rewind-stack))))))

	    (define-inline (state-entry-with-error-action state-index)
	      (assq 'error (vector-ref action-table state-index)))

	    (define (synchronise-lexer/skip-tokens error-state-index)
	      (let* ((error-actions	   (vector-ref action-table error-state-index))
		     (error-categories (map car (cdr error-actions))))
		(let skip-token ((token lookahead))
		  (let ((category (<lexical-token>-category token)))
		    (cond ((eq? category '*eoi*) ;unexpected end-of-input while trying to recover
			   token)
			  ((memq category error-categories) ;recovery success
			   ;;The following  stack entries will  be processed
			   ;;by  REDUCE-USING-DEFAULT-ACTIONS,  causing  the
			   ;;evaluation  of  the  semantic  action  for  the
			   ;;"error" right-hand  side rule.
			   ;;
			   ;;We want  $1 set  to "error" and  $2 set  to the
			   ;;recovery synchronisation token value.
			   (stack-push! #f 'error)
			   (stack-push! (cdr (assq category error-actions))
					(<lexical-token>-value token))
			   (lexer))
			  (else
			   (skip-token (lexer))))))))

	    (%main))

	  (define-inline (current-state)
	    (car stack-states))

	  (define-inline (stack-push! state value)
	    (set! stack-states (cons state stack-states))
	    (set! stack-values (cons value stack-values)))

	  (define-inline (stack-pop!)
	    (set! stack-states (cdr stack-states))
	    (set! stack-values (cdr stack-values)))

	  (main (lexer))))

      (case-lambda
       ((true-lexer error-handler)
	(parser-instance true-lexer error-handler #f))
       ((true-lexer error-handler yycustom)
	(parser-instance true-lexer error-handler yycustom))))


    (define (make-infix-sexp-parser)
      (lr-driver
       '#(((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . -19))
	  ((*default* . -16) (LPAREN . 10))
	  ((*default* . *error*)
	   (*eoi* . 24)
	   (QUESTION-ID . 23)
	   (ADD . 22)
	   (SUB . 21)
	   (MUL . 20)
	   (DIV . 19)
	   (DIV0 . 18)
	   (MOD . 17)
	   (EXPT . 16)
	   (LT . 15)
	   (GT . 14)
	   (LE . 13)
	   (GE . 12)
	   (EQ . 11))
	  ((*default* . -15)
	   (EQ . 11)
	   (GE . 12)
	   (LE . 13)
	   (GT . 14)
	   (LT . 15)
	   (EXPT . 16)
	   (MOD . 17)
	   (DIV0 . 18)
	   (DIV . 19)
	   (MUL . 20))
	  ((*default* . -14))
	  ((*default* . *error*)
	   (QUESTION-ID . 23)
	   (RPAREN . 25)
	   (ADD . 22)
	   (SUB . 21)
	   (MUL . 20)
	   (DIV . 19)
	   (DIV0 . 18)
	   (MOD . 17)
	   (EXPT . 16)
	   (LT . 15)
	   (GT . 14)
	   (LE . 13)
	   (GE . 12)
	   (EQ . 11))
	  ((*default* . -21) (SUB . 1) (ADD . 2) (LPAREN . 3) (NUM . 4) (ID . 5))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . -1) (*eoi* . accept))
	  ((*default* . -20))
	  ((*default* . *error*) (RPAREN . 41))
	  ((*default* . -24)
	   (EQ . 11)
	   (GE . 12)
	   (LE . 13)
	   (GT . 14)
	   (LT . 15)
	   (EXPT . 16)
	   (MOD . 17)
	   (DIV0 . 18)
	   (DIV . 19)
	   (MUL . 20)
	   (SUB . 42)
	   (ADD . 43)
	   (LPAREN . 3)
	   (NUM . 4)
	   (QUESTION-ID . 23)
	   (ID . 5))
	  ((*default* . -13))
	  ((*default* . -12))
	  ((*default* . -11))
	  ((*default* . -10))
	  ((*default* . -9))
	  ((*default* . -8) (EQ . 11) (GE . 12) (LE . 13) (GT . 14) (LT . 15))
	  ((*default* . -7) (EQ . 11) (GE . 12) (LE . 13) (GT . 14) (LT . 15) (EXPT . 16))
	  ((*default* . -6) (EQ . 11) (GE . 12) (LE . 13) (GT . 14) (LT . 15) (EXPT . 16) (MOD . 17))
	  ((*default* . -4) (EQ . 11) (GE . 12) (LE . 13) (GT . 14) (LT . 15) (EXPT . 16) (MOD . 17))
	  ((*default* . -5) (EQ . 11) (GE . 12) (LE . 13) (GT . 14) (LT . 15) (EXPT . 16) (MOD . 17))
	  ((*default* . -3)
	   (EQ . 11)
	   (GE . 12)
	   (LE . 13)
	   (GT . 14)
	   (LT . 15)
	   (EXPT . 16)
	   (MOD . 17)
	   (DIV0 . 18)
	   (DIV . 19)
	   (MUL . 20))
	  ((*default* . -2)
	   (EQ . 11)
	   (GE . 12)
	   (LE . 13)
	   (GT . 14)
	   (LT . 15)
	   (EXPT . 16)
	   (MOD . 17)
	   (DIV0 . 18)
	   (DIV . 19)
	   (MUL . 20))
	  ((*default* . *error*)
	   (QUESTION-ID . 23)
	   (COLON-ID . 46)
	   (ADD . 22)
	   (SUB . 21)
	   (MUL . 20)
	   (DIV . 19)
	   (DIV0 . 18)
	   (MOD . 17)
	   (EXPT . 16)
	   (LT . 15)
	   (GT . 14)
	   (LE . 13)
	   (GE . 12)
	   (EQ . 11))
	  ((*default* . -17))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . -22))
	  ((*default* . -24)
	   (EQ . 11)
	   (GE . 12)
	   (LE . 13)
	   (GT . 14)
	   (LT . 15)
	   (EXPT . 16)
	   (MOD . 17)
	   (DIV0 . 18)
	   (DIV . 19)
	   (MUL . 20)
	   (SUB . 42)
	   (ADD . 43)
	   (LPAREN . 3)
	   (NUM . 4)
	   (QUESTION-ID . 23)
	   (ID . 5))
	  ((*default* . *error*) (ID . 5) (NUM . 4) (LPAREN . 3) (ADD . 2) (SUB . 1))
	  ((*default* . -3)
	   (EQ . 11)
	   (GE . 12)
	   (LE . 13)
	   (GT . 14)
	   (LT . 15)
	   (EXPT . 16)
	   (MOD . 17)
	   (DIV0 . 18)
	   (DIV . 19)
	   (MUL . 20))
	  ((*default* . -2)
	   (EQ . 11)
	   (GE . 12)
	   (LE . 13)
	   (GT . 14)
	   (LT . 15)
	   (EXPT . 16)
	   (MOD . 17)
	   (DIV0 . 18)
	   (DIV . 19)
	   (MUL . 20))
	  ((*default* . -23))
	  ((*default* . -18)
	   (EQ . 11)
	   (GE . 12)
	   (LE . 13)
	   (GT . 14)
	   (LT . 15)
	   (EXPT . 16)
	   (MOD . 17)
	   (DIV0 . 18)
	   (DIV . 19)
	   (MUL . 20)
	   (SUB . 21)
	   (ADD . 22)
	   (QUESTION-ID . 23)))
       (vector
        '((1 . 6))
        '((1 . 7))
        '((1 . 8))
        '((1 . 9))
        '()
        '()
        '()
        '()
        '()
        '()
        '((2 . 26) (1 . 27))
        '((1 . 28))
        '((1 . 29))
        '((1 . 30))
        '((1 . 31))
        '((1 . 32))
        '((1 . 33))
        '((1 . 34))
        '((1 . 35))
        '((1 . 36))
        '((1 . 37))
        '((1 . 38))
        '((1 . 39))
        '((1 . 40))
        '()
        '()
        '()
        '((3 . 44) (1 . 45))
        '()
        '()
        '()
        '()
        '()
        '()
        '()
        '()
        '()
        '()
        '()
        '()
        '()
        '()
        '((1 . 47))
        '((1 . 48))
        '()
        '((3 . 49) (1 . 45))
        '((1 . 50))
        '()
        '()
        '()
        '())
       (vector
        '()
        (lambda (yy-reduce-pop-and-push yypushback yycustom yy-stack-states $2 $1 . yy-stack-values)
          $1)
        (lambda (yy-reduce-pop-and-push
		 yypushback
		 yycustom
		 yy-stack-states
		 $3
		 $2
		 $1
		 .
		 yy-stack-values)
          (yy-reduce-pop-and-push 3 1 (list $2 $1 $3) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push
		 yypushback
		 yycustom
		 yy-stack-states
		 $3
		 $2
		 $1
		 .
		 yy-stack-values)
          (yy-reduce-pop-and-push 3 1 (list $2 $1 $3) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push
		 yypushback
		 yycustom
		 yy-stack-states
		 $3
		 $2
		 $1
		 .
		 yy-stack-values)
          (yy-reduce-pop-and-push 3 1 (list $2 $1 $3) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push
		 yypushback
		 yycustom
		 yy-stack-states
		 $3
		 $2
		 $1
		 .
		 yy-stack-values)
          (yy-reduce-pop-and-push 3 1 (list $2 $1 $3) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push
		 yypushback
		 yycustom
		 yy-stack-states
		 $3
		 $2
		 $1
		 .
		 yy-stack-values)
          (yy-reduce-pop-and-push 3 1 (list $2 $1 $3) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push
		 yypushback
		 yycustom
		 yy-stack-states
		 $3
		 $2
		 $1
		 .
		 yy-stack-values)
          (yy-reduce-pop-and-push 3 1 (list $2 $1 $3) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push
		 yypushback
		 yycustom
		 yy-stack-states
		 $3
		 $2
		 $1
		 .
		 yy-stack-values)
          (yy-reduce-pop-and-push 3 1 (list $2 $1 $3) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push
		 yypushback
		 yycustom
		 yy-stack-states
		 $3
		 $2
		 $1
		 .
		 yy-stack-values)
          (yy-reduce-pop-and-push 3 1 (list $2 $1 $3) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push
		 yypushback
		 yycustom
		 yy-stack-states
		 $3
		 $2
		 $1
		 .
		 yy-stack-values)
          (yy-reduce-pop-and-push 3 1 (list $2 $1 $3) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push
		 yypushback
		 yycustom
		 yy-stack-states
		 $3
		 $2
		 $1
		 .
		 yy-stack-values)
          (yy-reduce-pop-and-push 3 1 (list $2 $1 $3) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push
		 yypushback
		 yycustom
		 yy-stack-states
		 $3
		 $2
		 $1
		 .
		 yy-stack-values)
          (yy-reduce-pop-and-push 3 1 (list $2 $1 $3) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push
		 yypushback
		 yycustom
		 yy-stack-states
		 $3
		 $2
		 $1
		 .
		 yy-stack-values)
          (yy-reduce-pop-and-push 3 1 (list $2 $1 $3) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push yypushback yycustom yy-stack-states $2 $1 . yy-stack-values)
          (yy-reduce-pop-and-push 2 1 $2 yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push yypushback yycustom yy-stack-states $2 $1 . yy-stack-values)
          (yy-reduce-pop-and-push 2 1 (list $1 $2) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push yypushback yycustom yy-stack-states $1 . yy-stack-values)
          (yy-reduce-pop-and-push 1 1 $1 yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push
		 yypushback
		 yycustom
		 yy-stack-states
		 $4
		 $3
		 $2
		 $1
		 .
		 yy-stack-values)
          (yy-reduce-pop-and-push 4 1 (cons $1 $3) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push
		 yypushback
		 yycustom
		 yy-stack-states
		 $5
		 $4
		 $3
		 $2
		 $1
		 .
		 yy-stack-values)
          (yy-reduce-pop-and-push 5 1 (list $2 $1 $3 $5) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push yypushback yycustom yy-stack-states $1 . yy-stack-values)
          (yy-reduce-pop-and-push 1 1 $1 yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push
		 yypushback
		 yycustom
		 yy-stack-states
		 $3
		 $2
		 $1
		 .
		 yy-stack-values)
          (yy-reduce-pop-and-push 3 1 $2 yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push yypushback yycustom yy-stack-states . yy-stack-values)
          (yy-reduce-pop-and-push 0 2 '() yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push yypushback yycustom yy-stack-states $2 $1 . yy-stack-values)
          (yy-reduce-pop-and-push 2 2 (cons $1 $2) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push yypushback yycustom yy-stack-states $2 $1 . yy-stack-values)
          (yy-reduce-pop-and-push 2 3 (cons $1 $2) yy-stack-states yy-stack-values))
        (lambda (yy-reduce-pop-and-push yypushback yycustom yy-stack-states . yy-stack-values)
          (yy-reduce-pop-and-push 0 3 '() yy-stack-states yy-stack-values)))))


    (lambda (stx)
      (syntax-case stx ()
	((?infix ?operand ...)
	 (let ((stx-lst (syntax->list #'(?operand ...))))
	   (cond ((null? stx-lst)
		  #'(values))
		 ((not (pair? stx-lst))
		  stx-lst)
		 (else
		  (let ((tokens (reverse (stx-list->reversed-tokens stx-lst '()))))
		    ((make-infix-sexp-parser) ;parser function
		     (lambda ()		      ;lexer function
		       (if (null? tokens)
			   $eoi
			 (let ((t (car tokens)))
			   (set! tokens (cdr tokens))
			   t)))
		     (lambda (message token) ;error handler
		       (syntax-violation 'infix
			 (string-append "processing infix expression: " message)
			 (syntax->datum #'(?infix ?operand ...)) token))
		     #f))))))))))


;;;; done

)

;;; end of file
