
twiki.Function = {

	/**
	Easy inheritance, see http://blogger.xs4all.nl/peterned/archive/2006/01/12/73948.aspx
	@param inClass : (Function) Function object to extend
	@param inSuperClass : (Function) Function object to extend from
	@return The extended inClass Function object.
	@use
	<pre>
		function AThing() {}
		function BThing(lorem, ipsum, dolor) {}
		BThing = twiki.twikiFunction.extendClass(BThing, AThing);
		// BThing prototype functions here...
	</pre>
	*/
	extendClass:function(inClass, inSuperClass) {
		var Self = inClass;
		var Func = function() {
			inSuperClass.apply(inClass, arguments);
			Self.apply(inClass, arguments);
		};
		Func.prototype = new inSuperClass();
		return Func;
	}
};