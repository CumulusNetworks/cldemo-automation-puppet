
# Any node that doesn't fit into another category will use the default node
# instead.
node default {

}

# We use the hostname to figure out what roles we should be assigning to the
# node. For leaves and spines, we can use a catch-all regular expression.
node /^leaf\d+.simulation$/ {
    include quagga
    include ifupdown2
}

node /^spine\d+.simulation$/ {
    include quagga
    include ifupdown2
}


node server02.simulation {
    include ifupdown
}

node server02.simulation {
    include ifupdown
    include apache
}
