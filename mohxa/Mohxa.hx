﻿package mohxa;
    //Simple test runner with simple logging
    //MIT License, based on https://github.com/visionmedia/mocha 

typedef MohxaHandler = Void->Void;


class MohxaRunnable {
    public var runner : Mohxa;
    public var name : String;
    public var run : MohxaHandler;

    public var before : MohxaHandler;
    public var after : MohxaHandler;
    public var beforeEach : MohxaHandler;
    public var afterEach : MohxaHandler;

    public function new(_runner:Mohxa, _name:String, _run:MohxaHandler) {
        runner = _runner; name = _name; run = _run;
        init();
    }

    public function init() {

    }


}

class MohxaTest extends MohxaRunnable {    
        //test cases stored in this test
    public var set : MohxaTestSet;

}

class MohxaFailure {

    public var details : String = 'Unknown';
    public var stack : Array<haxe.CallStack.StackItem>;
    public var test : MohxaTest;

    public function new(_det:String, _test:MohxaTest) {
        details = _det;
        test = _test;
        stack = haxe.CallStack.exceptionStack();
    }

    public function display(t:Int) {
        var _parsed = test.runner.strip_mohxa_calls(stack);
        for(item in _parsed) {
            Sys.println( test.runner.tabs(t) + item );
        }
    }

}

class MohxaTestSet extends MohxaRunnable {

    public var tests : Array<MohxaTest>;
    public var groups : Array<MohxaTestSet>;
    public var depth : Int = 0;
    var group_index : Int = 0;

    public function add_group( _group:MohxaTestSet ) {
        _group.depth = depth+1;
        groups.push( _group );
        // trace( runner.tabs(depth) + ' > adding group ' + _group.name + ' at ' + (depth+1));
    }
    public function add_test( _test:MohxaTest ) { 
        _test.set = this;
        tests.push( _test );
        // trace( runner.tabs(depth) + ' > adding test ' + _test.name );
    }

    public override function init() {
        tests = [];
        groups = [];
    }

    public function _traverse() {

        if( before != null ) before();

        var n = Math.pow(10,3);
        
        for(test in tests) {
            
            runner.current_depth = test.set.depth+1;

            if( beforeEach != null ) beforeEach();

            try {
                runner.onrun(test);

                var test_time = haxe.Timer.stamp();

                    test.run();

                test_time = (haxe.Timer.stamp() - test_time) * 1000; test_time = (Std.int(test_time*n) / n);

                    runner.onpass(test, test_time);

            } catch(e:Dynamic) {

                runner.onfail( new MohxaFailure(e,test) );

            } //catch

            if( afterEach != null ) afterEach();
        } //for each test
    
        for(group in groups) {
            runner.current_depth = depth;
            runner.current_set = group;
            Sys.println(runner.tabs(depth) + group.name );
            group.run();
            group._traverse();
        } //for each group

        runner.current_depth = 0;

        if( after != null ) after();
    }    

}

class Mohxa {

    var test_sets : Mohxa.MohxaTestSet;
    var symbols : Dynamic;
    var failed : Int = 0;
    var failures : Map<Int, MohxaFailure>;
    var total : Int = 0;
    var total_time : Float = 0;
    var system_name : String = '';

    public var current_depth : Int = 0;
    public var current_set : Mohxa.MohxaTestSet;

// Class specifics
    public function new() { 
        failures = new Map();
        create_root_set();
        system_name = Sys.systemName();
        if(system_name == "Windows") {
            symbols = { ok: 'ok', err: '!!', dot: '>' };
        } else {
            symbols = { ok: '✓', err: '✖', dot: '▸' };
        }
    } //new
    function create_root_set() {
        current_set = test_sets = new Mohxa.MohxaTestSet(this, '', null);
        test_sets.init();
    } //create_root_set

    public function strip_mohxa_calls(list:Array<haxe.CallStack.StackItem>) : Array<String> {
        var results = [];
        for(item in list) {
            var _params = item.getParameters();
            if( Std.string(_params[1]).indexOf('Mohxa.hx') == -1) {
                results.push( ' at ' + _params[1] + ':' + _params[2] );
            }
        }

        return results;
    }

    public function log(e:Dynamic) {
        var _parsed = strip_mohxa_calls( haxe.CallStack.callStack() );
        Sys.println( tabs(current_depth+2) + dim() + _parsed[0] + ': ' + e + reset() );
    }

    public function run() {

        Sys.println('\n');

        failed = 0;
        total_time = haxe.Timer.stamp();

            test_sets._traverse();

        total_time = (haxe.Timer.stamp() - total_time) * 1000;
        var n = Math.pow(10,3); total_time = (Std.int(total_time*n) / n);

        Sys.println('\n');
        
        if(failed > 0) {
            Sys.println( error() + ' ' + failed + ' of ' + total + ' failed  (' + dim() + total_time + 'ms' + reset() + ') \n' );
                //display all failures
            var _f : Int = 0;            
            for(failure in failures) {
                Sys.println( tabs(1) + red() + _f  + ') ' + reset() + failure.test.name  );
                Sys.println( tabs(2) + error() + dim() + ' because ' + reset() + red() + failure.details + reset() );
                Sys.print( dim() );
                failure.display(3);
                doreset();
                _f++;
            }
        } else {
            Sys.println( ok() + green() + ' ' + total + ' tests completed. ' +reset()+ dim() + ' (' + total_time + 'ms' + ')' + reset());
        }

        Sys.println('\n');

        doreset();

    } //run

//Helpers

    @:noCompletion public function onfail( failure:MohxaFailure ) {        
        Sys.println( tabs(failure.test.set.depth+3) + error() + red() + ' fail (' + failed + ')'  + reset());
        failures.set( failed, failure );
        failed++;
    }

    @:noCompletion public function onrun(t:MohxaTest) {         
        Sys.println( tabs(t.set.depth+2) + dim() + dot() + ' ' + t.name +  reset() ); 
    }

    @:noCompletion public function onpass(t:MohxaTest, runtime:Float ) {
        var _time = '';
        if(runtime > 50 && runtime < 100) {
            _time = reset() + yellow() + ' (' + runtime + 'ms)';
        } else if(runtime > 100) {
            _time =  reset() + red() + ' (' + runtime + 'ms)';
        }

        Sys.println( tabs(t.set.depth+3) + ok() + green() + ' pass' + _time + reset() );
    }

//API
    
    public function it( desc:String, handler:MohxaHandler ) {
        total++;
        current_set.add_test( new MohxaTest(this, desc, handler) );
    }

    public function describe( name:String, handler:MohxaHandler ) {
        if(current_set != null) {
            current_set.add_group( new MohxaTestSet(this, name, handler) );            
        }
    }

    public function before( handler:MohxaHandler ) {
        current_set.before = handler;
    }

    public function after( handler:MohxaHandler ) {
        current_set.after = handler;
    }

    public function beforeEach( handler:MohxaHandler ) {
        current_set.beforeEach = handler;
    }

    public function afterEach( handler:MohxaHandler ) {
        current_set.afterEach = handler;
    }    


    public function equal(value:Dynamic, expected:Dynamic, ?tag:String = '') {
        if( value != expected ) {            
            throw (value + ' != ' + expected) + '  ' + ((tag.length>0) ? '('+tag+')' : '');
        } 
    }

    public function tabs(t:Int) { var s = ''; for(i in 0 ... (t*2)) { s+=' '; } return s; }

    function doreset()  { Sys.print(reset()); }    
    function dot()      { return symbols.dot; }
    function reset()    { return (system_name == "Windows") ? '' : "\033[0m";  }    
    function yellow()   { return (system_name == "Windows") ? '' : "\033[93m"; }
    function green()    { return (system_name == "Windows") ? '' : "\033[92m"; }
    function red()      { return (system_name == "Windows") ? '' : "\033[91m"; }
    function bright()   { return (system_name == "Windows") ? '' : "\033[1m";  }
    function dim()      { return (system_name == "Windows") ? '' : "\033[2m";  }    
    function ok()       { return (system_name == "Windows") ? symbols.ok : "\033[92m"+symbols.ok+"\033[0m"; }
    function error()    { return (system_name == "Windows") ? symbols.err : "\033[91m"+symbols.err+"\033[0m"; }
    
}