---
layout: post
title:  "使用 IAR Embedded Workbench IDE 做单元测试"
date:   2019-12-20 20:00:00 +0800
---

一、欢迎
=============
　　很高兴你能看到这篇文章，我将在这篇文章中介绍如何使用 IAR 做单元测试。

　　大部分嵌入式开发者一般都按照“编码——编译——运行——调试”的循环完成开发工作，这很可能只会用到 IAR Embedded Workbench IDE（以下简称“IAR”）极少一部分（同时也是最常用的）功能。实际上，IAR 为开发者提供了很多丰富的功能，使我们能做更多事情。

　　IAR 集成了“IAR C-SPY Debugger”，IAR C-SPY Debugger 里面又提供了“C-SPY Simulator”功能。它通过软件完整地模拟了目标处理器，使目标处理器的代码可以脱离硬件环境运行。这样就可以随时做单元测试而不必等待硬件环境就绪。对单元测试而言，这是一个极大的便利。顺便提一下，我使用的 IAR 版本是 IAR Embedded Workbench for ARM 8.32.3.20228。

二、创建工程
=============
　　创建一个名为“test”的 C 语言模板工程，然后打开工程选项菜单，在"General Option"选项中的“Library Configuration”选项卡中，按下图所示配置。

![debugger](/asserts/iar-ut/semihost.png)

　　Semihosting 是 ARM 处理器独有的特性。它能使 ARM 目标机通过调试器和主机通讯，或者使用主机的I/O设备。此功能可以单元测试程序使用 printf 等方法输出测试信息。非常方便。其他类型的处理器也会有相应的机制完成此任务。

　　接下来，在“Debugger”选项中将调试驱动选为“Simulator”。入下图所示：

![debugger](/asserts/iar-ut/debugger.png)

　　打开 main.c 文件，修改其中的代码。
```
/*main.c*/
#include <stdio.h>
int main()
{
    printf("Hello World\n");
    return 0;
}
```
　　这时候可以按“Ctrl+d”启动调试。进入调试界面后，选择“View”菜单的“Terminal I/O”，打开终端输入输出窗体。按“F5”继续运行代码，可以看到“Hello World”输出信息。这样，一个简单的工程就创建完成了。

三、添加单元测试框架
=============
　　C 语言的单元测试框架很多，在这里不一一详述。我选择了Unity，项目地址见文末参考资料。下载“Unity-2.5.0.tar.gz”并解压。分别从“Unity-2.5.0/src”、“Unity-2.5.0/extras/fixture/src”和“Unity-2.5.0/extras/memory/src”中找到下列文件，并复制到 test 的工程目录中。
```
unity.c
unity.h
unity_fixture.c
unity_fixture.h
unity_fixture_internals.h
unity_internals.h
unity_memory.c
unity_memory.h
```
　　在 test 工程中添加以上的所有“.c”源文件，然后新建一个“foo.c”源文件作为待测文件。在 foo.c 中添加如下内容：
```
/*foo.c*/
int add(int a, int b)
{
    return a + b;
}
```
　　再次修改 main.c，使用 Unity 框架，为 add 函数添加两个测试用例。
```
/*main.c*/
#include <stdio.h>
#include "unity_fixture.h"

extern int add(int a, int b);

static void run_all_test(void);

int main()
{
    const char *arg = "test";
    return UnityMain(1, &arg, run_all_test);
}

void run_all_test(void)
{
    RUN_TEST_GROUP(add);
}

TEST_GROUP(add);

TEST_SETUP(add)
{
}

TEST_TEAR_DOWN(add)
{
}

TEST(add, case1)
{
    TEST_ASSERT_EQUAL(2, add(1, 1));
}

TEST(add, case2)
{
    TEST_ASSERT_EQUAL(-3, add(-1, -2));
}

TEST_GROUP_RUNNER(add)
{
    RUN_TEST_CASE(add, case1);
    RUN_TEST_CASE(add, case2);
}

```
　　运行程序后，可以看到终端输出信息。这两个测试用例已经全部通过了。

　　如何设计测试用例不在本文的讨论范围内，感兴趣的读者可以阅读 James W. Grenning 著的[《Test Driven Development for Embedded C》](https://www.amazon.com/Driven-Development-Embedded-Pragmatic-Programmers-ebook/dp/B01D3TWF5M)。这本书从各个方面讲述了在嵌入式领域如何进行测试。

四、拓展
=============
　　在 test/settings 路径下，有这么几个文件：
```
test.Debug.cspy.bat
test.Debug.cspy.ps1
test.Release.cspy.bat
test.Release.cspy.ps1
```
　　Debug 和 release 表示配置，bat 表示 Windows 批处理程序，ps1 表示 Powershell 程序。在终端执行这些脚本可以调用 IAR C-SPY Debugger 运行程序，并且将结果输出至终端。这有助于自动化运行单元测试，我们以后还会详细讨论。

　　IAR 还提供了在终端中构建项目的工具，更多内容请参考[这里](https://www.iar.com/support/tech-notes/general/build-from-the-command-line/)。

五、参考资料
=============
* https://github.com/ThrowTheSwitch/Unity
* http://www.keil.com/support/man/docs/armcc/armcc_pge1358787046598.htm
