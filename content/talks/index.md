---
title: "Talks"
date: 2025-10-06
summary: "A collection of talks I've given over the years - covering Scala, developer tooling, and the occasional ergonomic rabbit hole."
---

{{< talks-grid >}}

{{< talk-card
    title="Armadillo - Typesafe JSON-RPC API"
    event="Functional Scala"
    location="London"
    year="2022"
    slides="https://slides.com/kasperkondzielski-1/deck-be6dc7"
    recording="https://www.youtube.com/watch?v=mR8sRNQhBFw&t=273s&ab_channel=Ziverge"
    tags="Scala, JSON-RPC, Tapir, OpenRPC"
>}}
Although jsonrpc is not the most popular protocol, nowadays mostly replaced by grpc, there are still places that use it, especially in the case of inter-process communication. The two most popular ones are blockchains and language server protocol. Up until now, there was no idiomatic scala library for building api using that protocol. I would like to present the work that we did at IOG that resulted in the creation of a new library - armadillo, that takes similar approach to the commonly known, and well received library for building http endpoints - tapir. As its older brother, armadillo allows you to describe your jsonrpc endpoints using pure values and later interpret them to your liking - be it http server or openrpc documentation.
{{< /talk-card >}}

{{< talk-card
    title="Keyboard Layout Tinkering"
    event="Warsaw JUG (meetup #298)"
    location="Warsaw"
    year="2023"
    slides="https://slides.com/kasperkondzielski-1/keyboard-layout-tinkering"
    tags="Ergonomics, Colemak, Keybindings"
>}}
Recently I decided to improve the ergonomy of my workplace(home), which lead me to a discovery of the rabbit hole of custom keyboards. After a few months of research, it turned out that is not even a rabbit hole but a real mine shaft straight to hell. During this presentation I will tell you why I decided to switch to colemak, what are the pros and cons of using a different layout, what happened to all my keybindings, what are space cadet and autoshift, and how I ended up using only 42 keys of my 54-keys keyboard.
{{< /talk-card >}}

{{< talk-card
    title="Modern Terminal Environments"
    event="Art of Scala"
    location="Warsaw"
    year="2022"
    slides="https://github.com/ghostbuster91/modern-terminals-slides"
    tags="Shell, tmux, Vim, Nix, DX"
>}}
Despite the rapid development of very powerful IDEs like Intellij Idea, that are supposed to help in every aspect of software development, good old terminal is still an intrinsic element of our daily work. Configuration of the terminal is much more than just bunch of aliases and nice looking colors. During this presentation, I will show you how you can configure your terminal environment, so that your job will be more pleasant and efficient. We will start from a very basic shell configuration and gradually add more, following what I have done over the years. While doing that, we will always try to have our configuration version-able and easily reproducible. There will be a little bit of everything: shells, terminals, shell plugins, shell plugin managers, aliases, tmux, vim and nix.
{{< /talk-card >}}

{{< talk-card
    title="Writing Scala Outside of IntelliJ IDEA"
    event="Scalar"
    location="Warsaw"
    year="2022"
    slides="https://slides.com/kasperkondzielski-1/deck"
    recording="https://youtu.be/exTEBNuXWR8?si=CZSTf_r1eA8SynCA"
    tags="Scala, Neovim, Metals, LSP, Tree-sitter"
>}}
While this seemed to be impossible a few years ago, it all has changed with the rise of such projects as LSP(metals in our case) and tree-sitter. During this presentation, I will show you how you can build your own IDE for scala based on my nvim setup. We will cover parts that are most essential both from the perspective of writing scala and general software development. We will talk about metals, bloop, lsp, code navigation, making the editor more interactive, and why I decided to use such a setup in favor of Intellij Idea, which I have been using for years.
{{< /talk-card >}}

{{< talk-card
    title="Polyglot Development Environment"
    event="Ya!vaConf"
    location="Warsaw"
    year="2023"
    slides="https://slides.com/kasperkondzielski-1/polyglot-developer"
    tags="Nix, direnv, LSP, Tree-sitter, Neovim"
>}}
Modern software development is rarely limited to a single programming language. The evolution of technology and the demands of AI have necessitated developers to work with various programming languages, configurations, and tools built upon diverse software stacks. The days when proficiency in just one technology, such as Java, was sufficient seem to be inevitably over. Now, more than ever, there is a pressing need for robust IDE support.
While tools like IntelliJ IDEA and VS Code are continually improving, they do have limitations. In this presentation, I aim to showcase an alternative approach that I use in my day-to-day scala job: a method that harnesses modern tools such as Nix, direnv, LSP, Tree-sitter, and Neovim to create a consistent, polyglot developer environment. This environment can be easily versioned and replicated, offering a solution to the challenges faced in contemporary software development.
{{< /talk-card >}}

{{< /talks-grid >}}

