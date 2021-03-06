functor LLRBcreate(O: ORDERED) : BST = struct
	structure Ordered = O;

	type elt = Ordered.element;

	datatype color = RED|BLACK;

	datatype 'k btree = 
		Empty
	|	Node of {value : 'k, left : 'k btree, right : 'k btree, color : color};

	datatype compare = LESS|GREATER|EQUAL;

	fun assert (b,s) = if b then () else raise Fail ("Assertion failed: " ^ s);

	fun	cmp (x,y) =
		if Ordered.lt(x,y) then LESS
		else if Ordered.lt(y,x) then GREATER
		else EQUAL;

	val create = Empty;

	fun	rotateleft {
		right = x as Node{left=xl, right=xr, value=xv, color=RED},
		left = l,
		value = v,
		color = c
	} =
		let
			val h = Node{right=xl, color=RED, left=l, value=v}
		in
			{left=h, color=c, right=xr, value=xv}
		end
	|	rotateleft(_) = raise Fail("Tried to rotateleft on a bad node.");

	fun	rotateright {
		left = x as Node{left=xl, right=xr, value=xv, color=RED},
		right = r,
		value = v,
		color = c
	} =
		let
			val h = Node{left=xr, color=RED, right=r, value=v}
		in
			{right=h, left=xl, color=c, value=xv}
		end
	|	rotateright(_) = raise Fail("Tried to rotateright on a bad node.");

	fun	flip {
		color = c,
		left = Node{color=lc, value=lv, left=ll, right=lr},
		right = Node{color=rc, value=rv, left=rl, right=rr},
		value = v
	} =
		let
			fun	flipcolor RED = BLACK
			|	flipcolor BLACK = RED
		in
			assert (lc = rc, "Flip colors do not match");
			{
				color = flipcolor c,
				left = Node{color=flipcolor lc, value=lv, left=ll, right=lr},
				right = Node{color=flipcolor rc, value=rv, left=rl, right=rr},
				value = v
			}
		end
	|	flip(_) = raise Fail("Tried to flip on a bad node.")

	fun	isred Empty = false
	|	isred (Node{color = BLACK, ...}) = false
	|	isred (Node{color = RED, ...}) = true;

	fun	lookup (Empty,x) = NONE
	|	lookup (Node{value = y, left=l, right=r, ...},x) = (
			assert ((not (isred r)), "Red is on the right");
			assert ((not (isred l) orelse (
				case l of
					Node{left=ll, ...} => not (isred ll)
				|	_ => raise Fail("Impossible.")
			)), "Two reds in a row");
			case cmp(x,y) of
				LESS => lookup (l,x)
			|	GREATER => lookup (r,x)
			|	EQUAL => SOME y
		);

	fun insertfix (h as {left=l, right=r, ...}) =
		if isred l andalso isred r then flip h
		else if isred l andalso (
			case l of
				Node{left=ll, ...} => isred ll
			|	Empty => raise Fail("Impossible.")
		) then flip (rotateright h)
		else if isred r then rotateleft h
		else h;

	fun	insert1 (Empty,x) = Node{value=x, left=Empty, right=Empty, color=RED}
	|	insert1 (Node{value=v, left=l, right=r, color=c}, x) =
		let
			val h = case cmp(x,v) of
				LESS => {value=v, left=insert1(l,x), right=r, color=c}
			|	GREATER => {value=v, left=l, right=insert1(r,x), color=c}
			|	EQUAL => {value=x, left=l, right=r, color=c};
			val h = insertfix h
		in
			Node h
		end;

	fun	insert (t,x) =
		let
			val t = insert1 (t, x)
		in
			case t of
				Node{color=BLACK, ...} => t
			|	Node{color=RED, left=l, right=r, value=v} =>
					Node{color=BLACK, left=l, right=r, value=v}
			|	_ => raise Fail("Result of insertion was Empty.")
		end;

	fun	moveredleft h =
		let
			val h as {right=r, left=l, value=v, color=c} = flip h
		in
			case r of
				Node(rnode as {left=rl, ...}) =>
					if isred(rl) then
						let
							val rnode = rotateright rnode
							val h = {right=Node rnode, left=l, color=c, value=v};
						in
							flip (rotateleft h)
						end
					else h
			|	_ => raise Fail("Tried to moveredleft on a bad node.")
		end;

	fun	moveredright h =
		let
			val h as {left=l, ...} = flip h
		in
			case l of
				Node{left=ll, ...} =>
					if isred ll then
						flip (rotateright h)
					else h
			|	_ => raise Fail("Tried to moveredright on a bad node.")
		end;

	fun deletefix (h as {left=l, right=r, ...}) =
		if isred l andalso isred r then flip h
		else if isred r then rotateleft h
		else h;

	fun	deletemin Empty = (NONE, Empty)
	|	deletemin (Node(h as {left=l, value=v, ...})) =
		case l of
			Empty => (SOME v, Empty)
		|	Node{left=ll, ...} =>
			let
				val {left=l, right=r, color=c, value=v} =
					if not(isred l) andalso not(isred ll) then
						moveredleft h
					else h;
				val (vopt, dl) = deletemin l;
				val h = {left=dl, right=r, color=c, value=v}
			in
				(vopt, Node(deletefix h))
			end;


	fun	delete1 (Empty,x) = (false,Empty)
	|	delete1 (Node(h as {value=v, left=l, ...}),x) =
		let
			val (suc, h) = case cmp (x,v) of
				LESS => dless (h,x)
			|	_ => dgeq (h,x)
		in
			case h of
				Empty => (suc, Empty)
			|	Node h => (suc, Node(deletefix h))
		end
	and	dless (h as {left=l, ...}, x) =
		case l of
			Empty => (false, Node h)
		|	Node{left=ll, ...} =>
			let
				val {left=l, right=r, color=c, value=v} =
					if not(isred l) andalso not(isred ll) then
						moveredleft h
					else h;
				val (suc, dl) = delete1 (l,x)
			in
				(suc, Node{left=dl, right=r, value=v, color=c})
			end
	and	dgeq (h as {left=l, ...}, x) = 
		let
			val h as {right=r, value=v, ...} =
				if isred l then rotateright h
				else h
		in
			case r of
				Empty =>
					if cmp (x,v) = EQUAL then (true, Empty)
					else (false, Node h)
			|	Node {left=rl, ...} =>
				let
					val {right=r, left=l, value=v, color=c} =
						if not(isred r) andalso not(isred rl) then
							moveredright h
						else h
				in
					case cmp (x,v) of
						EQUAL =>
						let
							val (del, dr) = deletemin r
						in
							case del of
								SOME delv => (true, Node{right=dr, value=delv, left=l, color=c})
							|	NONE => (false, Node{right=dr, value=v, left=l, color=c})
						end
					|	_ =>
						let
							val (suc, dr) = delete1 (r,x)
						in
							(suc, Node{right=dr, left=l, value=v, color=c})
						end
				end
		end;

	fun	delete (Empty,x) = (false, Empty)
	|	delete (t,x) =
		let
			val (suc,t) = delete1 (t,x)
		in
			case t of
				Node{color=BLACK, ...} => (suc, t)
			|	Node{color=RED, left=l, right=r, value=v} =>
					(suc, Node{color=BLACK, left=l, right=r, value=v})
			|	Empty => (true, Empty)
		end;

	fun	optcmp (x,NONE) = EQUAL
	|	optcmp (x,SOME y) = cmp(x,y);

	fun	map _ _ Empty = []
	|	map f (min,max) (Node{left=l, right=r, value=v, ...}) =
		let
			val llist = map f (min,max) l;
			val rlist = map f (min,max) r
		in
			if optcmp (v,min) = LESS orelse optcmp (v,max) = GREATER then
				llist @ rlist
			else llist @ (f v)::rlist
		end;

	fun	app _ _ Empty = ()
	|	app f (min,max) (Node{left=l, right=r, value=v, ...}) = (
			app f (min,max) l;
			if optcmp(v,min) = LESS orelse optcmp(v,max) = GREATER then
				()
			else f v;
			app f (min,max) r
		);

	fun test t = ();

	fun toString _ _ = "";
end;
