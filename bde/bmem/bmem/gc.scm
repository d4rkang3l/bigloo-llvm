;*=====================================================================*/
;*    serrano/prgm/project/bigloo/bde/bmem/bmem/gc.scm                 */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Sun Apr 20 09:53:55 2003                          */
;*    Last change :  Wed Aug 11 14:29:29 2010 (serrano)                */
;*    Copyright   :  2003-10 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Visualize GC information                                         */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module bmem_gc
   (import  html
	    bmem
	    bmem_tools
	    bmem_function
	    bmem_type)
   (include "html.sch")
   (export  (make-gc-tables ::pair-nil ::pair-nil ::pair-nil)))

;*---------------------------------------------------------------------*/
;*    make-gc-tables ...                                               */
;*---------------------------------------------------------------------*/
(define (make-gc-tables gcmon fun* types)
   (let* ((gc* (cdr gcmon))
	  (maxhsize (apply max (map caddr gc*)))
	  (nbtypes (+fx 1 (apply max (map car (cdr types)))))
	  (tvec (make-vector nbtypes)))
      (for-each (lambda (t)
		   (vector-set! tvec (car t) (cadr t)))
		(cdr types))
      (html-table
       :width "100%"
       `(,(html-tr
	   `(,(html-td
	       :valign "top"
	       (make-gc-function-table maxhsize gc* fun*))
	     ,(html-td
	       :valign "top"
	       (make-gc-type-table maxhsize gc* fun* nbtypes tvec))))))))

;*---------------------------------------------------------------------*/
;*    make-gc-function-table ...                                       */
;*---------------------------------------------------------------------*/
(define (make-gc-function-table maxhsize::int gc*::pair-nil fun*::pair-nil)
   (define (gc->cell gc)
      (let* ((n (car gc))
	     (hsize (caddr gc))
	     (asize (cadr gc))
	     (per 0)
	     (sum 0)
	     (cell* (map (lambda (f)
			    (let* ((fgc (funinfo-find-gc f n))
				   (size (if (pair? fgc)
					     (cadr fgc)
					     0))
				   (nf (funinfo-num f))
				   (id (format "function~a" nf)))
			       (set! sum (+fx sum size))
			       (set! per (+fx per (% size maxhsize)))
			       (list (% size maxhsize)
				     id
				     (format "~a: ~ak (~a%)"
					     (function-ident-pp
					      (funinfo-ident f))
					     (word->kb size)
					     (% size asize)))))
			 fun*)))
	 (if (>=fx (absfx (-fx asize sum)) 1024)
	     (warning "make-gc-function-table"
		      "incorrect allocation size --"
		      " GC=" n " sum=" sum " alloc=" asize
		      " delta=" (-fx asize sum)))
	 (append cell*
		 (list (list (-fx (% hsize maxhsize) per)
			     "gc0"
			     (format "heap size: ~ak"
				     (word->kb (caddr gc))))))))
   (let* ((gc* (filter (lambda (gc)
			  (>fx (cadr gc) 0))
		       gc*))
	  (allsize (apply + (map cadr gc*)))
	  (cell* (map gc->cell gc*))
	  (row* (map (lambda (gc cells)
			(let* ((size (cadr gc))
			       (msize (caddr gc))
			       (size% (% size maxhsize))
			       (num (integer->string (+fx 1 (car gc))))
			       (id (string-append "gc" num))
			       (tdl (html-color-item id num))
			       (tds (html-td :class "size"
					     :align "left"
					     (format "~a% (~ak/~ak)"
						     size%
						     (word->kb size)
						     (word->kb msize)))))
			   (list (html-row-gauge cells tdl tds)
				 (html-tr (list (html-td :colspan 102 ""))))))
		     gc* cell*))
	  (srow (html-tr (list (html-td "")
			       (html-td :colspan 100
					:align "right"
					:class "olegend"
					"overall allocated memory:")
			       (html-td :align "left"
					:class "osize"
					(if (>fx allsize 1024)
					    (format "~aKB (~aMB)"
						    (word->kb allsize)
						    (word->mb allsize))
					    (format "~aKB"
						    (word->kb allsize))))))))
      (html-profile (append (apply append row*) (list srow))
		    "gc-function" "Gc (functions)"
		    '("gc" "8%")
		    '("memory" "20%"))))

;*---------------------------------------------------------------------*/
;*    make-gc-type-table ...                                           */
;*---------------------------------------------------------------------*/
(define (make-gc-type-table maxhsize::int gc*::pair-nil fun*::pair-nil
			    nbtypes tvecnames)
   (define (gc->cell gc)
      (let ((n (car gc))
	    (tvec (make-type-vector nbtypes))
	    (hsize (caddr gc))
	    (asize (cadr gc))
	    (per 0)
	    (sum 0))
	 (define (mark-function! f)
	    (let* ((dtype (funinfo-dtype f))
		   (dtypegc (assq n dtype)))
	       (if (and (pair? dtypegc) (pair? (cdr dtypegc)))
		   (for-each (lambda (dt)
				(let ((n (car dt))
				      (s (caddr dt)))
				   (set! sum (+fx s sum))
				   (vector-set! tvec
						n
						(+fx s (vector-ref tvec n)))))
			     (cdr dtypegc)))))
	 (for-each mark-function! fun*)
	 (let ((cell* (mapv (lambda (t i)
			       (let ((id (format "type~a" i))
				     (p (% (vector-ref tvec i) maxhsize)))
				  (set! per (+fx per p))
				  (list p
					id
					(format "~a (~a%)"
						(vector-ref tvecnames i)
						(% (vector-ref tvec i) sum)))))
			    tvec)))
	    (append cell*
		    (list (list (-fx (% hsize maxhsize) per)
				"gc0"
				(format "heap size: ~ak"
					(word->kb (caddr gc)))))))))
   (let* ((gc* (filter (lambda (gc)
			  (>fx (cadr gc) 0))
		       gc*))
	  (allsize (apply + (map cadr gc*)))
	  (cell* (map gc->cell gc*))
	  (row* (map (lambda (gc cells)
			(let* ((size (cadr gc))
			       (msize (caddr gc))
			       (size% (% size maxhsize))
			       (num (integer->string (+fx 1 (car gc))))
			       (id (string-append "gc" num))
			       (tdl (html-color-item id num))
			       (tds (html-td :class "size"
					     :align "left"
					     (format "~a% (~ak/~ak)"
						     size%
						     (word->kb size)
						     (word->kb msize)))))
			   (list (html-row-gauge cells tdl tds)
				 (html-tr (list (html-td :colspan 102 ""))))))
		     gc* cell*)))
      (html-profile (apply append row*)
		    "gc-function" "Gc (types)"
		    '("gc" "8%")
		    '("memory" "20%"))))
