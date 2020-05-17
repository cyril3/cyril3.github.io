---
layout: post
title:  "修复 Linux 中的一个噪音问题"
date:   2020-05-17 10:53:00 +0800
---

&emsp;&emsp;自从安装了 Kubuntu 20.04 后，我被一个噪音问题困扰了很久。系统在播放声音前，总会发出一两声短促的噪音。然后继续正常播放声音。后来经过一些研究，我在不久前解决了这个问题。

&emsp;&emsp;刚安装完操作系统后，我安装了媒体播放器，体验音乐和电影的播放效果。在操作过程中，我注意到系统偶尔会发出的短促噪音。在网上搜索一阵，并且尝试了一些方法后，问题没有得到解决。我便放弃了，只当是驱动程序可能有缺陷。

&emsp;&emsp;不过我渐渐地发现了一个规律：噪音只会在一段安静时间后，再次播放声音前产生。在持续播放声音过程中，从来没有噪音。这让我猜测到了一种可能的原因：系统在播放声音一段时间后可能会关闭音频设备，然后在下一次播放前再打开音频设备。打开音频设备的过程中有可能产生电信号的突变，继而产生短促的噪音。这种设计极有可能是基于省电的考虑。

&emsp;&emsp;于是，我以“Linux save power audio noise”为关键词搜索了一番。在 Redhat 公开的 BUG 管理系统中，我找到了2017年报告的一个 BUG：[《Bug 1525104 - Clicking noise when start or stop sound playing》](https://bugzilla.redhat.com/show_bug.cgi?id=1525104)。

&emsp;&emsp;这个 BUG 所描述的问题和我的相同，并且 Jeremy 似乎给出了解决问题的办法。
>Jeremy Cline 2017-12-13 18:06:49 UTC
>
>&emsp;Can you pass snd_hda_intel.power_save=0 on the kernel command line and see if that resolves your issue?
>
>&emsp;Thanks
>
>Riku Seppala 2017-12-13 18:25:50 UTC
>
>&emsp;Yes, that seems to resolve this for me.

&emsp;&emsp;这个方案虽然可行，但需要通过修改 grub 的配置来修改内核命令行参数。即有风险又麻烦，普通用户不好操作。我决定找一个更容易操作的方法。

&emsp;&emsp;“snd_hda_intel.power_save=0”看起来是把“snd_hda_intel”内核模块的“power_save”参数设置为0。那么问题应该是出在这个内核模块上了。于是我下载了 ubuntu 的内核源码，找到了这个内核模块。经过一番搜索，找到了这部分代码(linux-source-5.4.0/sound/pci/hda/hda_intel.c)：
```
#ifdef CONFIG_PM
static int param_set_xint(const char *val, const struct kernel_param *kp);
static const struct kernel_param_ops param_ops_xint = {
	.set = param_set_xint,
	.get = param_get_int,
};
#define param_check_xint param_check_int

static int power_save = CONFIG_SND_HDA_POWER_SAVE_DEFAULT;
module_param(power_save, xint, 0644);
MODULE_PARM_DESC(power_save, "Automatic power-saving timeout "
		 "(in second, 0 = disable).");

static bool pm_blacklist = true;
module_param(pm_blacklist, bool, 0644);
MODULE_PARM_DESC(pm_blacklist, "Enable power-management blacklist");

/* reset the HD-audio controller in power save mode.
 * this may give more power-saving, but will take longer time to
 * wake up.
 */
static bool power_save_controller = 1;
module_param(power_save_controller, bool, 0644);
MODULE_PARM_DESC(power_save_controller, "Reset controller in power save mode.");
#else
#define power_save	0
#endif /* CONFIG_PM */
```
&emsp;&emsp;阅读这段代码后，我发现 power_save 参数并非简单地开启或者关闭省电模式，而是一个超时时间。增大超时时间可以降低进入省电模式的频率，从而减少噪音产生的次数。设置0可以直接关闭省电模式。于是问题就变得简单了，我的台式电脑似乎并不那么在乎功耗，所以我决定关闭音频设备的省电模式。用这条命令可暂时关闭省电模式。系统重启后失效。
```
$ sudo echo 0 > /sys/module/snd_hda_intel/parameters/power_save
```
&emsp;&emsp;若要永久关闭设备的省电模式，在/etc/modprobe.d/中添加一个“disable_snd_hda_intel_power_save.conf”文件，在文件中添加这一行：
```
options snd_hda_intel power_save=0
```

### 一个更深入的问题

&emsp;&emsp;为什么 Linux 中有这个问题，而 Windows 操作系统中没有？

&emsp;&emsp;Linux 的文档中有一个章节：[More Notes on HD-Audio Driver](https://www.kernel.org/doc/html/v5.4/sound/hd-audio/notes.html)。这一节中介绍了 HD-audio 设备的大致结构。这里引用其中一段：
>The HD-audio component consists of two parts: the controller chip and the codec chips on the HD-audio bus. Linux provides a single driver for all controllers, snd-hda-intel. Although the driver name contains a word of a well-known hardware vendor, it’s not specific to it but for all controller chips by other companies. Since the HD-audio controllers are supposed to be compatible, the single snd-hda-driver should work in most cases. But, not surprisingly, there are known bugs and issues specific to each controller type. The snd-hda-intel driver has a bunch of workarounds for these as described below.

&emsp;&emsp;这里说：HD-audio 组件由控制器芯片和解码芯片组成。Linux 提供了控制器芯片的驱动程序。在 snd_hda_intel 模块中，我找到了解码芯片的省电模式的驱动代码(linux-source-5.4.0/sound/pci/hda/hda_codec.c)：

```
static void codec_set_power_save(struct hda_codec *codec, int delay)
{
	struct device *dev = hda_codec_dev(codec);

	if (delay == 0 && codec->auto_runtime_pm)
		delay = 3000;

	if (delay > 0) {
		pm_runtime_set_autosuspend_delay(dev, delay);
		pm_runtime_use_autosuspend(dev);
		pm_runtime_allow(dev);
		if (!pm_runtime_suspended(dev))
			pm_runtime_mark_last_busy(dev);
	} else {
		pm_runtime_dont_use_autosuspend(dev);
		pm_runtime_forbid(dev);
	}
}
```
&emsp;&emsp;原来音频设备的低功耗是通过控制解码芯片来实现的。于是我猜测电脑主板上应该有这样一个解码芯片：在省电模式中断电，在工作模式中供电。

&emsp;&emsp;我使用的是华硕 B85M-F 型号的主板，在华硕的官网中搜到了此主板的[规格说明](https://www.asus.com/au/Motherboards/B85MF/specifications/)。此主板搭载了 Realtek® ALC887 8-Channel High Definition Audio CODEC 音频解码芯片。我又在网上找到了这个芯片的数据手册，里面有它的长相和引脚定义。它长这个样子：

![debugger](/asserts/linux-popup-noise/ALC887.png)

&emsp;&emsp;我在电脑主板上找到了这个芯片，然后把 snd_hda_intel 模块的省电模式打开，用万用表在它的供电引脚上量到了电平的变化。正如我之前猜测的一样：播放声音一段时间后，停止供电。播放声音前，恢复供电。

&emsp;&emsp;最后，我抱着试试看的态度，换了一块硬盘，装上 Windows 10。经过半个多小时的测试，这个音频解码芯片的供电始终没有被切断。看来，Windows下的驱动并没有在低功耗方面理会此芯片。

&emsp;&emsp;到此，这个问题不再扑朔迷离。然而这个问题引发了我更深地思考：当此问题初现的时候，我的第一印象是 Linux 在这些细节上处理的还不够成熟。然而经过以上研究过程，我认为是 Linux 的开发人员追求极致的风格导致了这些琐碎的问题。上文提及的2017年报告的 BUG，到现在依然被开发者们追踪并修改，我为这些开发者们的精神所折服。
<p align="right">——2020年5月17日</p>
