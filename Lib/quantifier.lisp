(defun pc-model (pc csp)
  (let* ((scene (csp:scenario-consistency pc :first csp))
	 (relrep (calculi:calculus-relation-representation pc))
	 (encoder (relations:relation-representation-encoder relrep)))
      (if (typep scene 'csp:constraint-network)
	  (let* ((objs (csp:constraint-network-objects csp))
		 (rel< (ofunc:ofuncall encoder relrep "<"))
		 (rel> (ofunc:ofuncall encoder relrep ">"))
		 (rel= (ofunc:ofuncall encoder relrep "="))
		 (eqcluster (mapcar #'list objs)))
	    (dolist (c (csp:constraints scene))
	      (when (eq (csp:constraint-relation c) rel=)
		(let ((c1 (find-if #'(lambda (cl) (find (csp:constraint-object-1 c) cl)) eqcluster))
		      (c2 (find-if #'(lambda (cl) (find (csp:constraint-object-2 c) cl)) eqcluster)))
		  (unless (eq c1 c2)
		    (setq eqcluster (cons (append c1 c2) (delete c1 (delete c2 eqcluster))))))))
	    (let ((looping? t))
	      (loop while looping? do
		   (setq looping? nil)
		   (dolist (c (csp:constraints scene)) ;; FIXME: really need to look at all constraints in scene? isn't csp enough to look at?
		     (when (eq (csp:constraint-relation c) rel<)
		       (let ((p1 (position-if #'(lambda (cl) (find (csp:constraint-object-1 c) cl)) eqcluster))
			     (p2 (position-if #'(lambda (cl) (find (csp:constraint-object-2 c) cl)) eqcluster)))
			 (when (> p1 p2)
			   (rotatef (nth p1 eqcluster) (nth p2 eqcluster))
			   (setq looping? t))))
		     (when (eq (csp:constraint-relation c) rel>)
		       (let ((p1 (position-if #'(lambda (cl) (find (csp:constraint-object-1 c) cl)) eqcluster))
			     (p2 (position-if #'(lambda (cl) (find (csp:constraint-object-2 c) cl)) eqcluster)))
			 (when (< p1 p2)
			   (rotatef (nth p1 eqcluster) (nth p2 eqcluster))
			   (setq looping? t)))))))
	    (let ((pos 0))
	      (mapcan #'(lambda (cl)
			  (incf pos)
			  (mapcar #'(lambda (c) (list c pos)) cl))
		      eqcluster)))
	  scene)))

(defun symNameEQ (s1 s2)
  (equal (symbol-name s1) (symbol-name s2)))

(defun allen-model (allen csp)
  (let* ((scene (csp:scenario-consistency allen :first csp))
	 (relrep (calculi:calculus-relation-representation allen))
	 (encoder (relations:relation-representation-encoder relrep)))
    ;;(format t "~%Allen CSP: ~a" scene)
    (if (typep scene 'csp:constraint-network)
	(let* ((objs2points ())
	       (point-constraints ()))
	  (dolist (o (csp:constraint-network-objects csp))
	    (let ((start (intern (symbol-name (gensym (symbol-name o))))) ; must not use gensym here since symbols get re-read!!
		  (end   (intern (symbol-name (gensym (symbol-name o))))))
	      (push (list o start end) objs2points)	      
	      (push (list start '< end) point-constraints)))
	  ;;(format t "~&~a~%" objs2points)
	  (dolist (c (csp:constraints scene))
	    (let ((s1 (second (assoc (csp:constraint-object-1 c) objs2points)))
		  (e1 (third (assoc (csp:constraint-object-1 c) objs2points)))
		  (s2 (second (assoc (csp:constraint-object-2 c) objs2points)))
		  (e2 (third (assoc (csp:constraint-object-2 c) objs2points)))
		  (r (csp:constraint-relation c)))
	      (cond ((equal r (ofunc:ofuncall encoder relrep "EQ"))
		     (push (list s1 '= s2) point-constraints)
		     (push (list e1 '= e2) point-constraints))
		    ((equal r (ofunc:ofuncall encoder relrep "B"))
		     (push (list e1 '< s2) point-constraints))
		    ((equal r (ofunc:ofuncall encoder relrep "BI"))
		     (push (list e2 '< s1) point-constraints))
		    ((equal r (ofunc:ofuncall encoder relrep "D"))
		     (push (list s2 '< s1) point-constraints)
		     (push (list e1 '< e2) point-constraints))
		    ((equal r (ofunc:ofuncall encoder relrep "DI"))
		     (push (list s1 '< s2) point-constraints)
		     (push (list e2 '< e1) point-constraints))		    
		    ((equal r (ofunc:ofuncall encoder relrep "O"))
		     (push (list s1 '< s2) point-constraints)
		     (push (list s2 '< e1) point-constraints)
		     (push (list e1 '< e2) point-constraints))
		    ((equal r (ofunc:ofuncall encoder relrep "OI"))
		     (push (list s2 '< s1) point-constraints)
		     (push (list s1 '< e2) point-constraints)
		     (push (list e2 '< e1) point-constraints))
		    ((equal r (ofunc:ofuncall encoder relrep "M"))
		     (push (list e1 '= s2) point-constraints))
		    ((equal r (ofunc:ofuncall encoder relrep "MI"))
		     (push (list e2 '= s1) point-constraints))
		    ((equal r (ofunc:ofuncall encoder relrep "S"))
		     (push (list s1 '= s2) point-constraints)
		     (push (list e1 '< e2) point-constraints))
		    ((equal r (ofunc:ofuncall encoder relrep "SI"))
		     (push (list s1 '= s2) point-constraints)
		     (push (list e2 '< e1) point-constraints))
		    ((equal r (ofunc:ofuncall encoder relrep "F"))
		     (push (list s1 '> s2) point-constraints)
		     (push (list e1 '= e2) point-constraints))
		    ((equal r (ofunc:ofuncall encoder relrep "F"))
		     (push (list s2 '> s1) point-constraints)
		     (push (list e1 '= e2) point-constraints)))))
	  ;;(format t "~%point-constraints = ~a " point-constraints)
	  (let ((pcm (sparq:dispatch-command (list "quantify" "pc" point-constraints))))
	    ;;(format t "~%point-constraints = ~a~%pcm = ~a~%" point-constraints pcm)
	    (mapcar #'(lambda (o)
			(list o (second (assoc (second (assoc o objs2points)) pcm :test #'symNameEQ)) (second (assoc (third (assoc o objs2points)) pcm :test #'symNameEQ))))
		    (csp:constraint-network-objects csp)))
	  )
	scene)))

(defun cardir-model (cardir csp)
  (let* ((scene (csp:scenario-consistency cardir :first csp))
	 (relrep (calculi:calculus-relation-representation cardir))
	 (encoder (relations:relation-representation-encoder relrep)))
    (if (typep scene 'csp:constraint-network)
	(let* ((points-x ())
	       (points-y ()))
	  (dolist (c (csp:constraints scene))
	    (let ((o1 (csp:constraint-object-1 c))
		  (o2 (csp:constraint-object-2 c))
		  (r (csp:constraint-relation c)))
	      (cond ((equal r (ofunc:ofuncall encoder relrep "EQ"))
		     (push (list o1 '= o2) points-x)
		     (push (list o1 '= o2) points-y))		      
		    ((equal r (ofunc:ofuncall encoder relrep "N"))
		     (push (list o1 '= o2) points-x)
		     (push (list o1 '> o2) points-y))
		    ((equal r (ofunc:ofuncall encoder relrep "S"))
		     (push (list o1 '= o2) points-x)
		     (push (list o1 '< o2) points-y))
		    ((equal r (ofunc:ofuncall encoder relrep "E"))
		     (push (list o1 '> o2) points-x)
		     (push (list o1 '= o2) points-y))
		    ((equal r (ofunc:ofuncall encoder relrep "W"))
		     (push (list o1 '< o2) points-x)
		     (push (list o1 '= o2) points-y))
		    ((equal r (ofunc:ofuncall encoder relrep "NE"))
		     (push (list o1 '> o2) points-x)
		     (push (list o1 '> o2) points-y))
		    ((equal r (ofunc:ofuncall encoder relrep "NW"))
		     (push (list o1 '< o2) points-x)
		     (push (list o1 '> o2) points-y))
		    ((equal r (ofunc:ofuncall encoder relrep "SE"))
		     (push (list o1 '> o2) points-x)
		     (push (list o1 '< o2) points-y))
		    ((equal r (ofunc:ofuncall encoder relrep "SW"))
		     (push (list o1 '< o2) points-x)
		     (push (list o1 '< o2) points-y)))))
	  (let ((model-x (sparq:dispatch-command (list "quantify" "pc" points-x)))
		(model-y (sparq:dispatch-command (list "quantify" "pc" points-y))))
	    (mapcar #'(lambda (xmod)
			(let* ((obj (first xmod))
			       (x   (second xmod))
			       (y   (find obj model-y :key #'first)))
			  (list obj x (second y))))
		    model-x))))))
			  
(defun block-algebra-model (ba csp)
  (let* ((scene (csp:scenario-consistency ba :first csp))
	 (relrep (calculi:calculus-relation-representation ba))
	 (decoder (relations:relation-representation-decoder relrep)))
    ;;(format t "~%scene = ~a~%" scene)
    (if (typep scene 'csp:constraint-network) ; alebraically closed scenario found?
	(let* ((cs-x ())
	       (cs-y ()))
	  (dolist (c (csp:constraints scene))
	    (let* ((o1 (csp:constraint-object-1 c))
		   (o2 (csp:constraint-object-2 c))
		   (r (ofunc:ofuncall decoder relrep (csp:constraint-relation c)))
		   (div (position #\_ r)) ; we know that relations are atomic, so this approach does the job...
		   (rx (subseq r 1 div))
		   (ry (subseq r (+ div 1) (- (length r) 1))))
	      ;; (format t "~% ~a (~a) --> ~a / ~a" r div rx ry)
	      (push (list o1 rx o2) cs-x)
	      (push (list o1 ry o2) cs-y)))
          ;;(format t "~%x-constraints = ~a~%y-constraints = ~a~%" cs-x cs-y)
	  (let ((model-x (sparq:dispatch-command (list "quantify" "allen" cs-x)))
		(model-y (sparq:dispatch-command (list "quantify" "allen" cs-y))))
	    ;;(format t "~&model-y = ~a~%" model-y)
	    (mapcar #'(lambda (xmod)
			(let* ((obj (first xmod))
			       (y (find obj model-y :key #'first)))
			  (list obj (second xmod) (second y) (third xmod) (third y))))
		    model-x))))))