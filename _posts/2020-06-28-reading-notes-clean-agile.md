---
layout:     post
title:      "Reading notes: Clean Agile"
subtitle:   "读书笔记：敏捷整洁之道"
date:       2020-6-28 00:15:00
author:     "Di Chen"
header-img: "img/in-post/reading-notes/agile-bg.jpg"
tags:
    - Tech
    - Agile
---


## 目录

[第一章：敏捷的起源](#第一章敏捷的起源)
 - [铁十字，项目中必须要做的权衡](#铁十字项目中必须要做的权衡)
 - [敏捷的目的](#敏捷的目的)
 - [管理项目的铁十字 (The Iron Cross)](#管理项目的铁十字-the-iron-cross)

[第二章：为什么要敏捷](#第二章为什么要敏捷)
 - [程序员的职业素养 (Professionalism)](#程序员的职业素养-professionalism)
 - [一些对程序员的合理的期望 (Reasonable Expectations)](#一些对程序员的合理的期望-reasonable-expectations)
 - [权利法案 (The Bill Of Rights)](#权利法案-the-bill-of-rights)

[第三章：敏捷的业务方实践](#第三章敏捷的业务方实践)

---

## 前言

在过去项目的开发和迭代过程中，遇到了不少业务方和开发方预期不一致导致的冲突，在所谓的”敏捷迭代“的过程中，也没有感受到敏捷带来的效率或者项目可控性的提升。学而不思则罔，思而不学则殆，于是带着工作中的疑问来阅读整洁系列的新作。

疑问1: 为什么直观感受上敏捷没有带来效率上的提升，每个时间周期内能做完的事情或者需求还是那么多？

疑问2: 为什么项目仍然会一直 delay？

这个读书笔记并不是一个完整的中文翻译，只摘取书中的关键观点，针对每个观点与我过去项目管理中的经验做对比，并提供一部分我自己的想法。

---

### 第一章：敏捷的起源

[第一章原文](http://book.chendi.me:8080/site/library/view/clean-agile-back/9780135782002/ch01.html)

敏捷的关键点其实是尽量保持人员的稳定，同时坚守对质量的维护。在这两个前提下，把时间点和需求量的取舍交给最终用户来进行。

---

#### 铁十字，项目中必须要做的权衡

> The reason that these techniques fail so spectacularly is that the managers who use them do not understand the fundamental physics of software projects. This physics constrains all projects to obey an unassailable trade-off called the Iron Cross of project management. Good, fast, cheap, done: Pick any three you like. You can’t have the fourth. You can have a project that is good, fast, and cheap, but it won’t get done. You can have a project that is done, cheap, and fast, but it won’t be any good.

观点总结：
 - 就像我们的日常生活被物理定律支配一样，软件开发也有基本规律。书中称为 *The Iron Cross* （铁十字），即：对于一个项目，在质量、速度、成本、完成度4个维度中挑选3个，舍弃一个，不会有一个项目能高质量、低成本、快速地把所有需求都完成。如果一个项目能低成本、快速地把所有需求都完成，这个项目一定质量不高。
 - 项目经理需要做好权衡，把这4个方面都做到足够好即可，不需要做到100%。

实际项目：
 - 在过去的软件开发项目中，质量意味着 bug 率和代码可维护性，交付的产品中有多少未修复的 bug，有多少单元测试覆盖。速度意味着一个需求的交付周期。成本意味着有多少人参与。完成度意味着有多少需求完成了，特别是一些为了使用体验而提出的优化需求。
 - 在上一个项目当中，项目初期有一个明确的完成时间点，且评估下来时间上很紧张，同时项目的范围的约束有简单的功能点罗列，所以在项目开始时，我们的权衡就是：
   - **质量 (Good) 70%**。因为我们在完成项目的同时希望可以做成一个可复制的产品，没有人愿意接手垃圾代码。所以单元测试、代码风格、同行评审是一开始就强制加在提交流程里的。但是对于一些不影响主流程的 bug，可能就决定暂不处理了。
   - **速度 (Fast) 90%**。由于项目的周期很紧，所以速度是最不能牺牲的一部分。
   - **成本 (Cheap) 50%**。由于内部人员的支持不足，成本上被迫做了很大的牺牲。
   - **完成度 (Done) 30%**。由于其他方面的限制能调整的空间太少，只能在完成度上做牺牲，对于用户体验不好的地方暂时不做处理，能把功能性需求完成就行。对于 UI 上不好看的地方也暂时不处理。

思考：
 - 和 CEO 的一个比较大的分歧就在于铁十字是不是能改变。对于 CEO 来说，一个公司的存亡往往意味着能以更低的成本(Cheap)、更快的速度(Fast)做出体验更好(Done\Good)的产品来满足客户。但是对于我来说，这个权衡是实实在在存在，并且得做的，而作出的牺牲都可能被归咎于团队的积极性和主观能动性不高，毕竟多改几个 bug （Good），多做几个需求（Done）都是可以通过加班来提高的嘛。
 - 在其他的资料中，也提到类似的看法，比如 Atlassian（做 Jira 的公司）提到 [The iron triangle of planning
](https://www.atlassian.com/agile/agile-at-scale/agile-iron-triangle) 。
   - 传统的项目管理有3个需要权衡的铁三角：工作范围（比如需求点和功能点）、资源（经济资源和人力资源）、时间（交付里程碑）。这3个被称为**铁**三角，就意味着在改变一个要素的情况下，是不可能不影响其他两个要素的。比如在增加需求的情况下，不加资源是不可能按原时间交付的。
   - 但是实际工作中，总是会有要求需求要全部做完，人员也没有额外的变动空间，时间节点也是限制死的。这时候大家是怎么办的呢？其他人的博客其实也提到过 [The Lie of the Iron Triangle
](https://medium.com/serious-scrum/the-lie-of-the-iron-triangle-6445e5e4fb26) 在这种情况下，其实牺牲的就是铁三角的第四个面，也就是当这三个条件无法组成三角形时，质量就流失了。我们会加班工作，跳过必要的测试步骤，压缩用户培训时间，压缩部署流程中的检验环节，跳过文档的撰写，不修复一些低优先的 bug。于是我们就交付了一个质量有问题的产品。作为这个产品的作者，程序员，无疑是悲哀的。

---

#### 敏捷的目的

> As the iterations progress, the error bars shrink until there is no point in hoping that the original date has any chance of success.

> This loss of hope is a major goal of Agile. We practice Agile in order to destroy hope before that hope can kill the project.

> 21. Sprint is the term used in Scrum. I dislike the term because it implies running as fast as possible. A software project is a marathon, and you don’t want to sprint in a marathon.


观点总结：
 - 敏捷迭代的目的不是使开发速度更快，也不是使项目不会 delay。恰恰相反，敏捷迭代的目的，是在早期把项目不会 delay 的希望给打碎，避免像瀑布式开发，到了交付前几天或者几周，才发现项目无法交付。
 - 敏捷迭代中每个迭代叫一个“冲刺”，但是这个词并不好，因为一个软件项目是一场马拉松，你不会想在跑马拉松的时候保持冲刺的姿态。

实际项目：
 - 实际工作中，“敏捷”往往给人一个感觉，”敏捷“迭代会使得项目开发的速度变快，这个其实从一开始就不是“敏捷”的意义。
 - 在我做的上一个项目中，其实并不需要敏捷迭代来预警，从一开始的项目计划排下来，就没办法排一个不 delay 的计划。

思考：
 - 敏捷的意义在于预警，在于可控性。可控性不意味着不会 delay，而是及早地把问题暴露出来，及早地采取措施解决问题。但是如果项目一开始就没有一个计划能不 delay，那么无论用什么项目管理或者迭代的方法，还有什么意义呢？ 当然有意义，项目的目标是实现商业价值，错过了时间可能会减少商业价值，所以不 delay 不能作为项目的最终目标之一，最终目标应该是以最大化项目的商业价值为目标。
 - 至此，疑问1和疑问2都被解释了，其实敏捷并没有打算解决我们认为的开发效率和项目 delay 的问题。那么敏捷团队是怎样看待并处理 delay 这件事情呢？

---

#### 管理项目的铁十字 (The Iron Cross)

> Remember, the date was chosen for good business reasons. Those business reasons probably haven’t changed. So a delay often means that the business is going to take a significant hit of some kind.

> Brooks’ law states: Adding manpower to a late project makes it later.

> Everyone knows that you can go much faster by producing crap. So, stop writing all those tests, stop doing all those code reviews, stop all that refactoring nonsense, and just code you devils, just code. Code 80 hours per week if necessary, but just code! Producing crap does not make you go faster, it makes you go slower. This is the lesson you learn after you’ve been a programmer for 20 or 30 years. There is no such thing as quick and dirty. 

> Anything dirty is slow.

> If the organization is rational, then the stakeholders eventually bow their heads in acceptance and begin to scrutinize the plan. One by one, they will identify the features that they don’t absolutely need by November. This hurts, but what real choice does the rational organization have? And so the plan is adjusted. Some features are delayed.

观点总结：
 - 当我们通过敏捷迭代开发了一段时间之后，我们可能会发现项目或者交付物会 delay，这时候怎么办呢？常见的方案有几个：
   - **修改交付目标时间点。**这个方案简单，但是往往后期会被作为一个事故诟病。
   - **加人。**根据 Brooks 定律，加人会导致项目进一步 delay。因为新人加入项目之后需要原项目组的人分配额外的时间进行培训和问题解答，会影响原项目组的人的效率，而新人往往要过几周才能不需要指导地完成工作，就意味着这几周内，效率是比原来要低的。但是如果时间够长，整体团队效率还是能较之前有提升的。
   - **降低质量。**这个方案往往是大多数人采取的方案。例如时间不够的时候，不写单元测试，不写注释，不写文档，不做代码评审，不做完整的回归测试，不做用户培训，不使用灰度发布。这样可以写出很多*脏*代码。但是做过20、30年开发的人都知道，没有哪个*脏*代码可以很快开发完成的，越*脏*的东西，越慢。
   - **砍需求，减少需求范围。**让用户放弃一部分需求是很困难的，特别是用户出资支持这个项目开发的时候，更难。但是如果整个组织和用户是理性的，在不修改时间的前提下，会很痛苦地接受这个事情，砍掉一部分需求。

实际项目：
 - 作为项目经理，无时不刻在面对这4个方案的选择，每个方案都需要克服一定的压力才可能落实。改时间的话往往意味着 KPI 不达成，或者合同违约。而砍需求对用户来说也是一个很痛苦的决定，这个对话也会很艰难。于是看似简单的方法就变成了加人或则会降低质量。在我上一个项目中，频繁的人员变化导致了许多的重复工作，项目背景、代码框架需要重新介绍，需要重新磨合，但却是项目慢慢变好的一个必经之路。而质量，则是最难坚守的一道坎。后端的代码一直坚持着单元测试，但是前端却很难用类似的方法进行覆盖管理，也是后续项目迭代越来越慢的一个原因。

思考：
 - 对于一个产品经理或者项目经理来说，最难的应该是坚守产品的质量，但在我看来，这也是区分一个平庸的项目经理和一个优秀项目经理的关键点。没有经历过软件开发的人，不会理解代码质量对于长期发展的影响有多深。
 - 敏捷的关键点其实是尽量保持人员的稳定，同时坚守对质量的维护。在这两个前提下，把时间点和需求量的取舍交给最终用户来进行。

---

### 第二章：为什么要敏捷

[第二章原文](http://book.chendi.me:8080/site/library/view/clean-agile-back/9780135782002/ch02.html)

敏捷迭代的目标和实施前提。

#### 程序员的职业素养 (Professionalism)

> We in this industry sorely need to increase our professionalism. We fail too often. We ship too much crap. We accept too many defects. We make terrible trade-offs. Too often, we behave like unruly teenagers with a new credit card. In simpler times, these behaviors were tolerable because the stakes were relatively low. In the ’70s and ’80s and even into the ’90s, the cost of software failure, though high, was limited and containable.

观点总结：
 - 在当今的社会，生活的方方面面已经离不开程序员的代码贡献了，app、网站、公共交通、政府、银行、医疗等等都被软件应用打通了。想象你写的那些代码会被作用到这些关键的领域，而你的一个 bug 可能导致他人损失金钱甚至生命，那我们对待手上的代码时，应该要保持更高地专业度和职业素养才行。

实际项目：
 - 在之前的项目中，即使我很希望能保持最高的专业度，所有代码都有测试用例覆盖，每个提交有对应的单元测试执行，每个环境的部署都有自动的健康检测等等。但是做这些事情短期看不到什么成果，而且会导致成本大幅上升，就根本推不下去。

思考：
 - 作为一个程序员，难的不是尽力写出好的代码，或者保持高的专业度，难的是上司或者领导迫于商业或者其他压力，要求你不写测试用例，不测试直接上线等等。

---

#### 一些对程序员的合理的期望 (Reasonable Expectations)

> What follows is a list of perfectly reasonable expectations that managers, users, and customers have of us. Notice as you read through this list that one side of your brain agrees that each item is perfectly reasonable. Notice that the other side of your brain, the programmer side, reacts in horror. The programmer side of your brain may not be able to imagine how to meet these expectations.

> Meeting these expectations is one of the primary goals of Agile development. The principles and practices of Agile address most of the expectations on this list quite directly. The behaviors below are what any good chief technology officer (CTO) should expect from their staff. Indeed, to drive this point home, I want you to think of me as your CTO. Here is what I expect.

观点总结：
 - 敏捷开发的一个主要目的是达到以下的一系列期望，这些期望是针对程序员的。可以把这些期望想象成敏捷开发的目标。敏捷的方法论就是为了达到这些期望而设计出来的。
   - **我们不交付垃圾 (We will Not Ship Shyt)。** 这个听起来是个废话，但是现实是，这确实需要作为一个期望提出。所以敏捷会强调测试、重构、简化设计，从而保证交付给客户的都是高质量的、用户友好的产品。
   - **技术上持续可部署 (Continous Technical Readiness)。** 敏捷要求在每个迭代结束的时候，系统都是处在一个可部署的状态。如果用户选择不部署更新，比如做完的功能点还不够多，或者商业时机没到，这是一个商业决定，这没关系。但是在每个迭代结束的时候，所有完成的功能都需要是写完代码、测试过、写清楚文档的。所以敏捷要求每个用户故事都足够小，从而保证可以在一个迭代中高质量地完成。
   - **稳定的产能 (Stable Productivity)。** 在项目一开始的时候，往往会发现功能做的很快，因为没有老的代码库的依赖，没有历史包袱，但是随着项目发展，同样复杂度的需求可能会需要花许多2-3倍的时间，这往往是很多非研发的客户或者管理者无法理解的。其实出现这个情况就意味着代码的架构设计或者逻辑结构有问题，需要优化或者重构，但是重构应该是随着每个需求小范围的进行的，不应该整体推翻重来。同样的，敏捷要求的测试、结对编程、重构和简化设计都是保持稳定产能的关键。
   - **低成本地进行修改 (Inexpensive Adaptability)。** 研发经常会抱怨需求一直变更，但是好的架构和好的程序设计应该是能灵活应对需求的变更的，如果无法灵活应对，则代表你的架构或者设计很差。程序员的意义也正是在于可以实现需求变更。同样的，敏捷要求的测试、结对编程、重构和简化设计都是保持低成本地进行修改的关键。
   - **代码的持续优化提升 (Continous Improvement)。无畏地把事情做好 (Fearless Competence)** 人类渐渐地把事情变得更好，代码也不应该例外，不应该因为时间的流逝，代码渐渐腐化。而代码的腐化往往出现在尝试走捷径的时候，例如一个需求做一个简单修改，但是留下一个 magic number，也可以做一个小重构，把变量抽离开，此时有很多人都会不敢做这个小重构，因为担心改出一些意外的 bug。但是如果有面向测试编程的支持，所有的需求都有自动化的测试用例，如果测试用例都跑过了就意味着没问题，那么我相信大部分程序员都不会害怕做这样的小重构。而敏捷推崇的结对编程、面向测试编程、重构、简化设计都是为了支持这一点。
   - **测试应该找不到问题 (QA Should Find Nothing) 应该尽量做自动化测试 (Test Automation)** 当 测试跑一遍他们的测试用例的时候，他们应该能得出系统一切正常的这个答案。当测试发现 bug 的时候，研发团队应该复盘在研发的流程中，哪一步出错了，从而保证下一次不会出现同样的问题。同样的，对于测试来说，重复的手工测试是耗时、昂贵、而且**不人道**的，如果留给测试时间不足的话，那么无论怎样对测试用例进行取舍，交付出去的都是一个没有被完整测试过的产品，所以我们应该用自动化测试来覆盖所有可以覆盖的测试用例，让测试只需要测那些无法自动化的部分。这也是让研发团队可以做到交付测试无 bug 的必经的一步。
   - **我们为其他人互相打掩护 (We Cover for Each Other)** 客户不会关心你的私人生活是不是有什么变故，生病、度假都不应该影响到整体，不应该让整个团队停摆。所以敏捷的结对编程、完整团队、集体拥有的思想都是为了达到这个目标的。
   - **诚实的预估 (Honest Estimates)** 所有的预估，都应该是诚实的。最诚实的预估是 “我不知道”。但是呢，即使一些事情自己不知道，也应该基于自己了解的信息提供一些信息。比如我们可能无法预估出某个任务可能需要花的时间有多长，但是我们可以和已经做过的事情比较，比如任务 A 比任务 B 简单，但是比任务 C 复杂，这也是非常有价值的。或者我们也可以给出不同置信度的预估，比如任务 A 有 5% 的可能在 3 天内完成，有 50% 的可能在 6 天内完成，有 95% 的可能在 20 天内完成。这个信息也可以给项目经理很多帮助。
   - **你需要说“不” (You Need to say no)** 即便我们工程师是为了解决问题而存在的，但是当事情没有一条可能完成的路径时，无论上级或者外部有多大的压力，也需要把 “No“ 说出来。敏捷的完整团队思想是为了支持这一点的。
   - **持续学习 (Continous Agressive Learning)** 无论公司支不支持，即使没有机会，也要自己创造机会去学习，从而适应这个快速变化的行业。
   - **做导师 (Mentoring)** 最好的学习方式是教其他人，所以尽量去做导师辅导新人。

实际项目：
   - 这是一个很长的期望列表，我也针对这个期望列表来对照看看在过去的项目中做的如何。
     - **我们不交付垃圾 (We will Not Ship Shyt)。** 这个可以说是意外地做得最差的一条。无论是在哪个公司，我都对过去交付的产品不够满意，在 Bloomberg，即使一个老牌的大公司，大部分代码也缺少单元测试，甚至很多代码都无法在业务流程中进行测试。而其他的创业公司，有一部分新项目有比较好的单元测试覆盖，但是也仍然缺少端到端的自动化测试，所以至今也没有一个产品或者公司是在这一条让我可以拍着胸脯说，我交付的产品我满意。
     - **技术上持续可部署 (Continous Technical Readiness)。** 意外的这一条倒是做的还不错，现在大部分的公司都有了自己的 CI 系统，可以在研发提交之后自动进行单元测试、自动部署。所以至少在每个迭代结束的时候，只要及时把 bug 修复，是可以做到持续可部署的。
     - **稳定的产能 (Stable Productivity)。** 这一点在 Bloomberg 这样的大公司做的是比较差的，因为历史包袱太严重，每个需求的修改都是牵一发而动全身，而大部分代码又没有单元测试，就大大拉低了整体团队的迭代速度。在熵简的我负责的项目中，后端的代码都是有完整的单元测试覆盖的，从而保证了整体后端迭代的速度并不太受时间影响而变化，但是前端的代码却没有这个覆盖，也导致了整体前端的迭代速度会相对较慢。不过前端的自动化测试也一直是一个国内外较难进行的工作。
     - **低成本地进行修改 (Inexpensive Adaptability)。** 这一条和 “稳定的产能“ 其实类似，在代码健康的情况下，整体的修改成本不会太高。但是有一点是敏捷没有提到的，在代码设计时，如果代码的底层逻辑是与实际业务设计贴近的，那么修改起来的成本也会和实际业务贴近，更容易被客户接受。例如某个实体是否是唯一的，是否作为可能被重用，在数据库、页面、处理 API 的定义上尽可能去和业务逻辑贴近，从而保证业务发起的修改复杂度更可控。
     - **代码的持续优化提升 (Continous Improvement)。无畏地把事情做好 (Fearless Competence)** 这一条无论在哪个公司，都没有很好地做到。一个是由于业务时间线的压力，当研发提出需要对某部分的代码进行重构的时候，业务领导往往不会支持这个人物的排期。另一个是由于程序员自身的恐惧，害怕由于自己修改了代码导致 bug，不光要熬夜加班改 bug，可能也会影响到自己的绩效。这两个问题，前者可以让领导认同敏捷的思想，从而推行定期清理技术债的行动。后者则一方面靠程序员的自我修养，另一方面靠敏捷的完整团队的意识，责任共担，从而让大家可以做对的事。
     - **测试应该找不到问题 (QA Should Find Nothing) 应该尽量做自动化测试 (Test Automation)** 我不认在国内任何一家公司能做到这个程度，在我呆过的公司也没有一家做到的。我认同这个思想，但是可能太理想化了。
     - **我们为其他人互相打掩护 (We Cover for Each Other)** 在 Bloomberg，所有的功能都有主负责任和副负责人，同时代码评审也很认真，所以很好地达到了这个要求。但是在创业公司，大部分人对这一点其实是排斥的，因为能暂时完成、替代其他人的工作往往被认为是工作内容不饱和，团队产能有冗余，管理层就会希望进一步压榨产能，直至团队成员缺一不可。
     - **诚实的预估 (Honest Estimates)** 与其说是诚实，不如说是有技巧地预估。当无法给出一个准确答案的时候，给出一个相对值或者概率值。但是这个在之前的项目中，给出相对预估的有，但是给出概率预估的我还没遇到。
     - **你需要说“不” (You Need to say no)** 这一点在之前的项目中基本没有做到。特别是创业公司，被扣了一顶帽子 “创业公司就是要把不可能完成的事情做成”，那这时所有的 “No” 就变成了和公司对着干的行为，是无法生存下去的。
     - **持续学习 (Continous Agressive Learning) 做导师 (Mentoring)** 这两点主要得看公司对于这两个行为的支持程度。Bloomberg 是完全支持的态度，但是创业公司往往都是明着或者暗着反对的态度，比如把工作量排到996或者007，基本也不会有时间进行额外的学习或者 Mentor 了。

思考：
 - 这些期望描绘了一个敏捷迭代的乌托邦，如果能达到 50% 基本就是一个不错的公司了，如果能达到 80%，就可以列上程序员的理想雇主了。
 - 预计在未来10年内，这些期望都不会完全被认同，比如自动化测试就需要很长的时间才能完成覆盖和补全，如果哪个公司能让程序员低成本地进行自动化测试，这家公司也会创造极大的财富。

---

#### 权利法案 (The Bill Of Rights)

> The goal of Agile was to heal the divide between business and development.

> Notice, as you read these rights, that the rights of the customer and the rights of the developer are complementary. They fit together like a hand in a glove. They create a balance of expectations between the two groups.

观点总结：
  - 敏捷的目的是修复业务方和研发方的鸿沟，而权利法案就是两方制衡的方案。
  - 用户不光指的是最终的使用者，也包括内部的产品经理和项目经理。
  - 用户的权利：
    - 用户有权知道整体的安排，以及每个需求完成所需的代价。
      - 整体的安排不代表在某个时间点一定会交付某个需求，要么需求点，要么时间点是需要可以进行调整的。需要可调整的并不意味着可以不预估，还是要预估一个带可能性的时间帮助用户处理相关事宜。
    - 用户有权知道每个迭代预计会完成的功能/需求/产出。
    - 用户有权在一个可以运行的系统上看到工作的的进度，可以尝试用不同的测试用例来验证。
    - 用户有权改主意，有权在花合理的代价的前提下改需求。
      - 修改需求或者功能是可以的，只要能对应付出价格/时间上的妥协，这也是软件开发行业存在的意义。而合理的代价意味着软件的设计应该是好的，灵活的，而不是需要推倒重来的。
    - 用户有权知道时间计划和工作量预估的变化，同时选择修改需求范围以保证某个时间点的交付。
    - 用户可以在任意一个时间点取消项目，并且拿到一个可以运行的，反映了至今为止投入的可以工作的系统。
  - 开发者包括研发、测试、需求分析师等。
  - 开发的权利：
    - 开发者有权知道每个需求的优先级和清晰的描述。
      - 这条要求了开发者拿到的需求是固定并清晰的。这个可能和前面用户能改需求的权利相违背，但主要区别在于时间范围。在一个迭代的内部，需求需要是固定并清晰的，在迭代和迭代之间，需求是可以变化的。
    - 开发者有权在任何时候高质量地完成工作。
      - 这条意味着，**不能因为需求做不完而要求开发者做出违背职业素养的事**，比如跳过测试、文档、代码审核，或指责明知有安全隐患却不处理。
      - 这条也许是最难的一条。
    - 开发者有权向同事、领导、客户寻求并获得帮助。
    - 开发者有权提出工作量预估，并且更新修改自己的工作量预估。
      - 预估不代表承诺。
      - 预估不可能准确，预估永远只是个预测值。
    - 开发者有权主动获取自己的责任范围，而不是被动分配。
  - 关键点1: 计划内，要么需求范围，要么时间点需要是灵活的，不能两个都是定死的。用户没有权利要求在某个时间点前一定要完成某些功能，用户只能通过修改需求范围来达到所需要的时间点。为了使用户能理性地作出这个判断，需要给他提供足够的信息，包括每个工作的预估时间和代价。
  - 关键点2: 不能因为需求做不完而要求开发者做出违背职业素养的事。

实际项目：
  - 在上一个项目中，用户的权利基本都是可以得到保障的，除了一点，就是当前项目的状态。项目的状态都是经过美化过的，没人愿意承认当前的项目当中问题一大堆，显得自己能力不行，但是哪个项目会是一帆风顺没有坎坷的呢？
  - 在上一个项目中，研发的权利是没办法得到保障的。
    - 无法高质量地完成工作。当需求来不及做的时候，第一处理方案总是加班，在加班的时候，开发者也很难保持一个完美主义的状态把事情做到 100 分，于是就产出了低质量的产品。如果第一处理方案也没法处理，第二处理方案往往是跳过测试、跳过文档、跳过审核，跳过这些看似不会立即产生价值的阶段。
    - 无法拿到清晰描述的需求和优先级。在面对强势的客户时，客户提出的需求在一个迭代内可以变化两三次，导致前一个需求还没测试完，需求就又变了。
    - 预估即承诺。在预估的时候，管理层认为预估应该要尽量贴近实际，所以偏长的预估往往会被 challenge。而在实际推进的时候，预估又被认为是“承诺”，导致“承诺”的时间内永远完不成工作。此时理性人的做法就是提高预估的时间，这样一来，用户就得不到真实的信息了。也违背了“诚实预估”的期望。

思考：
  - 如果在所有人都认同这个权利法案的前提下，项目的推进是可以在一个理性且高效的节奏里进行的，关键是**所有人**都认同这个权利法案。而这个关键就要求大家都了解到每个权利背后的原因，没有做过研发的人是很难理解的，比如为什么不能承诺某个事情在某个时间点前一定要完成。
  - 认同这个权利法案最好是在项目启动会的时候就提出，明确基调之后，后续的细则措施也会好推行很多。

---

### 第三章：敏捷的业务方实践

[第三章原文](http://book.chendi.me:8080/site/library/view/clean-agile-back/9780135782002/ch03.html)


---









