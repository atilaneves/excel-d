module ut.wrap.traits;

import test;
import xlld.wrap.traits;
import xlld.wrap.worksheet;


/// return a WorksheetFunction for a double function(double) with no
/// optional arguments
WorksheetFunction makeWorksheetFunction(wstring name, wstring typeText) @safe pure nothrow {
    return
        WorksheetFunction(
            Procedure(name),
            TypeText(typeText),
            FunctionText(name),
            Optional(
                ArgumentText(""w),
                MacroType("1"w),
                Category(""w),
                ShortcutText(""w),
                HelpTopic(""w),
                FunctionHelp(""w),
                ArgumentHelp([""w]),
                )
            );
}

///
WorksheetFunction doubleToDoubleFunction(wstring name) @safe pure nothrow {
    auto ret = makeWorksheetFunction(name, "BB"w);
    ret.optional.argumentText = ArgumentText("n");  // See test.xl_funcs.FuncMulByTwo
    return ret;
}

///
WorksheetFunction FP12ToDoubleFunction(wstring name) @safe pure nothrow {
    auto ret = makeWorksheetFunction(name, "BK%"w);
    ret.optional.argumentText = ArgumentText("cells");  // See test.xl_funcs.FuncFP12
    return ret;
}

///
WorksheetFunction operToOperFunction(wstring name) @safe pure nothrow {
    auto ret = makeWorksheetFunction(name, "UU"w);
    ret.optional.argumentText = ArgumentText("n");  // See test.xl_funcs.FuncFib
    return ret;
}

WorksheetFunction asyncFunction(wstring name) @safe pure nothrow {
    auto ret = makeWorksheetFunction(name, ">UX"w);
    ret.optional.argumentHelp.add("");  // FuncAsync has two parameters
    ret.optional.argumentText = ArgumentText("n;asyncHandle");
    return ret;
}

///
@("getWorksheetFunction for double -> double functions with no extra attributes")
@system pure unittest {
    extern(Windows) double foo(double n) nothrow @nogc { return 0; }
    getWorksheetFunction!foo.shouldEqual(doubleToDoubleFunction("foo"));

    extern(Windows) double bar(double n) nothrow @nogc { return 0; }
    getWorksheetFunction!bar.shouldEqual(doubleToDoubleFunction("bar"));
}

///
@("getWorksheetFunction for double -> int functions should fail")
@safe pure unittest {
    extern(Windows) double foo(int) { return 0; }
    getWorksheetFunction!foo.shouldThrowWithMessage("Unsupported function type double(int) for foo");
}

///
@("getworksheetFunction with @Register in order")
@system pure unittest {

    @Register(ArgumentText("my arg txt"), MacroType("macro"))
    extern(Windows) double foo(double) nothrow;

    auto expected = doubleToDoubleFunction("foo");
    expected.argumentText = ArgumentText("my arg txt");
    expected.macroType = MacroType("macro");

    getWorksheetFunction!foo.shouldEqual(expected);
}

///
@("getworksheetFunction with @Register out of order")
@system pure unittest {

    @Register(HelpTopic("I need somebody"), ArgumentText("my arg txt"))
    extern(Windows) double foo(double) nothrow;

    auto expected = doubleToDoubleFunction("foo");
    expected.argumentText = ArgumentText("my arg txt");
    expected.helpTopic = HelpTopic("I need somebody");

    getWorksheetFunction!foo.shouldEqual(expected);
}


@("getWorksheetFunction with @ExcelParameter")
@system pure unittest {
    extern(Windows) double withParamUDA(@ExcelParameter("the double") double d) nothrow;

    auto expected = doubleToDoubleFunction("withParamUDA");
    expected.optional.argumentHelp = ArgumentHelp("the double");
    expected.optional.argumentText = ArgumentText("d");

    getWorksheetFunction!withParamUDA.should == expected;
}


@safe pure unittest {
    extern(Windows) double doubleToDouble(double) nothrow;
    static assert(isWorksheetFunction!doubleToDouble);

    extern(Windows) LPXLOPER12 operToOper(LPXLOPER12) nothrow;
    static assert(isWorksheetFunction!operToOper);

    extern(Windows) void funcAsync(LPXLOPER12 n, LPXLOPER12 asyncHandle) nothrow;
    static assert(isWorksheetFunction!funcAsync);

    LPXLOPER12 operToOperWrongLinkage(LPXLOPER12) nothrow;
    static assert(isWorksheetFunctionModuloLinkage!operToOperWrongLinkage);
    static assert(!isWorksheetFunction!operToOperWrongLinkage);

    enum MyEnum { foo, bar, baz, }

    extern(Windows) MyEnum FuncEnumRet(LPXLOPER12 n) nothrow;
    static assert(!isWorksheetFunction!FuncEnumRet);

    extern(Windows) LPXLOPER12 FuncEnumArg(MyEnum _) nothrow;
    static assert(!isWorksheetFunction!FuncEnumArg);
}


@("getWorksheetFunctions on test.xl_funcs")
@system pure unittest {
    getModuleWorksheetFunctions!"test.xl_funcs".shouldEqual(
        [
            doubleToDoubleFunction("FuncMulByTwo"),
            FP12ToDoubleFunction("FuncFP12"),
            operToOperFunction("FuncFib"),
            asyncFunction("FuncAsync"),
        ]
    );
}

@("template mixin for getWorkSheetFunctions for test.xl_funcs")
unittest {
    import xlld.wrap.worksheet;

    // mixin the function here then call it to see if it does what it's supposed to
    mixin(implGetWorksheetFunctionsString!"test.xl_funcs");
    getWorksheetFunctions.shouldEqual(
        [
            doubleToDoubleFunction("FuncMulByTwo"),
            FP12ToDoubleFunction("FuncFP12"),
            operToOperFunction("FuncFib"),
            asyncFunction("FuncAsync"),
        ]
    );
}

@("implGetWorksheetFunctionsString runtime")
unittest {
    import xlld.wrap.worksheet;

    // mixin the function here then call it to see if it does what it's supposed to
    mixin(implGetWorksheetFunctionsString("test.xl_funcs"));
    getWorksheetFunctions.shouldEqual(
        [
            doubleToDoubleFunction("FuncMulByTwo"),
            FP12ToDoubleFunction("FuncFP12"),
            operToOperFunction("FuncFib"),
            asyncFunction("FuncAsync"),
        ]
    );
}


@("worksheet functions to .def file")
unittest {
    dllDefFile!"test.xl_funcs"("myxll32.dll", "Simple D add-in").shouldEqual(
        DllDefFile(
            [
                Statement("LIBRARY", "myxll32.dll"),
                Statement("EXPORTS",
                          [
                              "xlAutoOpen",
                              "xlAutoClose",
                              "xlAutoFree12",
                              "FuncMulByTwo",
                              "FuncFP12",
                              "FuncFib",
                              "FuncAsync",
                          ]),
            ]
        )
    );
}


@("getTypeText")
@safe pure unittest {
    import std.conv: to; // working around unit-threaded bug

    double foo(double);
    getTypeText!foo.to!string.shouldEqual("BB");

    double bar(FP12*);
    getTypeText!bar.to!string.shouldEqual("BK%");

    FP12* baz(FP12*);
    getTypeText!baz.to!string.shouldEqual("K%K%");

    FP12* qux(double);
    getTypeText!qux.to!string.shouldEqual("K%B");

    LPXLOPER12 fun(LPXLOPER12);
    getTypeText!fun.to!string.shouldEqual("UU");

    void void_(LPXLOPER12, LPXLOPER12);
    getTypeText!void_.to!string.shouldEqual(">UU");

    @Async
    void async(LPXLOPER12, LPXLOPER12);
    getTypeText!async.to!string.shouldEqual(">UX");
}
