/**
Easy inheritance, see http://blogger.xs4all.nl/peterned/archive/2006/01/12/73948.aspx
@use
<pre>
	function BThing(lorem, ipsum, dolor) {
	}
	BThing = BThing.extendsFrom(AThing);
	// prototype functions here...
</pre>
*/
Function.prototype.extendsFrom = function(Super) {
	var Self = this;
	var Func = function() {
		Super.apply(this, arguments);
		Self.apply(this, arguments);
	};
	Func.prototype = new Super();
	return Func;
}
