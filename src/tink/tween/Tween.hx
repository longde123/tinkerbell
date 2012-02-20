package tink.tween;

import haxe.FastList;
import haxe.Timer;
import tink.collections.ObjectMap;
import tink.lang.Cls;
import tink.tween.plugins.Plugin;
/**
 * ...
 * @author back2dos
 */
typedef TweenCallback = Void->Void;
typedef TweenComponent = Float->Null<TweenCallback>;
typedef TweenAtom<T> = T->TweenComponent;
private typedef Tweens = FastList<Tween<Dynamic>>;

class Tween<T> {
	public var target(default, null):T;
	public var progress(default, null):Float;
	public var duration(default, null):Float;
	public var group(default, null):TweenGroup;
	
	public var paused:Bool;
	
	var onDone:Void->Dynamic;
	var easing:Float->Float;
	var components:Array<TweenComponent>;
	var properties:Array<String>;
	
	inline function clamp(f:Float) {
		return
			if (f < .0) 0.0;
			else if (f > 1.0) 1.0;
			else f;
	}
	public function update(delta:Float):Float {
		return 
			if (paused) Math.POSITIVE_INFINITY;
			else {
				progress += delta / duration;
				var amplitude = easing(clamp(progress));
				for (c in components) 
					group.afterHeartbeat(c(amplitude));
				(1 - progress) * delta;				
			}
	}
	public function cleanup():Void {
		targetMap.get(target).remove(this);
		for (c in components) 
			c(Math.POSITIVE_INFINITY);
			
		onDone();
		this.target = null;
		this.easing = null;
		this.components = null;
		this.properties = null;
	}
	public function freeProperties(free:String->Bool):Void {
		var ps = [], cs = [], i = 0;
		for (p in properties) {
			if (free(p)) 
				components[i](Math.POSITIVE_INFINITY);
			else {
				ps.push(p);
				cs.push(components[i]);
			}
			i++;
		}
		this.properties = ps;
		this.components = cs;		
	}

	static var targetMap = new ObjectMap<Dynamic, Array<Tween<Dynamic>>>();
	static public function byTarget<A>(target:A):Iterable<A> {//returning Iterable here because we don't want people to screw around with this
		var ret = targetMap.get(target);
		if (ret == null)
			ret = targetMap.set(target, []);
		return cast ret;
	}
	static function register(tween:Tween<Dynamic>, kill:String->Bool) {
		if (targetMap.exists(tween.target)) 
			for (t in targetMap.get(tween.target))
				t.freeProperties(kill);
		else
			targetMap.set(tween.target, []);
		
		targetMap.get(tween.target).push(tween);
	}
	static public var defaultEasing = Math.sqrt;
}

class TweenParams<T> implements Cls {
	var propMap = new Hash<Bool>();
	var properties = new Array<String>();
	var atoms = new Array<TweenAtom<T>>();
	
	public var onDone:Tween<T>->Dynamic;
	public var duration = 1.0;
	public var easing = Tween.defaultEasing;
	
	public function new() {}
	static function ignore():Void { }
	
	public function start(group, target:T):Tween<T> {
		var ret = RealTween.get();
		ret.init(group, target, properties, atoms, propMap.exists, duration, easing, onDone == null ? ignore : callback(onDone, ret));
		return ret;
	}

	public function addAtom(name:String, atom:TweenAtom<T>):Void {
		if (!this.propMap.exists(name)) {
			this.propMap.set(name, true);
			this.properties.push(name);
			this.atoms.push(atom);
		}
	}
}

private class RealTween<T> extends Tween<T> {
	function new() {}
	static public function get<A>() {
		return new RealTween<A>();
	}
	public function init(group:TweenGroup, target:T, properties:Array<String>, atoms:Array<TweenAtom<T>>, exists, duration, easing, onDone) {
		this.onDone = onDone;
		this.group = group;
		this.target = target;
		this.properties = properties;
		this.components = [];
		this.duration = duration;
		this.easing = easing;
		
		Tween.register(this, exists);
		
		this.progress = 0;
		for (a in atoms)
			this.components.push(a(target));
		group.addTween(this);
	}
}