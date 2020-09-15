package Pod::Weaver::Plugin::Acme::CPANModules;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use Moose;
with 'Pod::Weaver::Role::AddTextToSection';
with 'Pod::Weaver::Role::Section';

use Pod::From::Acme::CPANModules qw(gen_pod_from_acme_cpanmodules);

sub _process_module {
    no strict 'refs';

    my ($self, $document, $input, $package) = @_;

    my $filename = $input->{filename};

    # XXX handle dynamically generated module (if there is such thing in the
    # future)
    local @INC = ("lib", @INC);

    {
        my $package_pm = $package;
        $package_pm =~ s!::!/!g;
        $package_pm .= ".pm";
        require $package_pm;
    }

    my $list = ${"$package\::LIST"};
    my $has_benchmark = 0;
  L1:
    for my $entry (@{ $list->{entries} }) {
        if (grep {/^bench_/} keys %$entry) {
            $has_benchmark = 1;
            last L1;
        }
    }

    (my $ac_name = $package) =~ s/\AAcme::CPANModules:://;

    my $res = gen_pod_from_acme_cpanmodules(
        module => $package,
        _raw=>1,
    );

    for my $section (sort keys %{$res->{pod}}) {
        $self->add_text_to_section(
            $document, $res->{pod}{$section}, $section,
            {
                (after_section => ['DESCRIPTION']) x ($section ne 'DESCRIPTION')
            },
        );
    }

    # XXX don't add if current See Also already mentions it
    my @pod = (
        "L<Acme::CPANModules> - about the Acme::CPANModules namespace\n\n",
        "L<cpanmodules> - CLI tool to let you browse/view the lists\n\n",
    );
    $self->add_text_to_section(
        $document, join('', @pod), 'SEE ALSO',
        {after_section => ['DESCRIPTION']
     },
    );

    # add FAQ section
    {
        my @pod;
        push @pod,
q(=head2 What are ways to use this module?

Aside from reading it, you can install all the listed modules using
L<cpanmodules>:

    % cpanmodules ls-entries ).$ac_name.q( | cpanm -n

or L<Acme::CM::Get>:

    % perl -MAcme::CM::Get=).$ac_name.q( -E'say $_->{module} for @{ $LIST->{entries} }' | cpanm -n

);
        if ($has_benchmark) {
            push @pod,
q(This module contains benchmark instructions. You can run a benchmark
for some/all the modules listed in this Acme::CPANModules module using
L<bencher>:

    % bencher --cpanmodules-module ).$ac_name.q(

);
        }

        push @pod,
q(This module also helps L<lcpan> produce a more meaningful result for C<lcpan
related-mods> when it comes to finding related modules for the modules listed
in this Acme::CPANModules module.

);
        $self->add_text_to_section(
            $document, join("", @pod), 'FAQ',
            {
                after_section => ['COMPLETION', 'DESCRIPTION'],
                before_section => ['CONFIGURATION FILE', 'CONFIGURATION FILES'],
                ignore => 1,
            });
    }

    $self->log(["Generated POD for '%s'", $filename]);
}

sub weave_section {
    my ($self, $document, $input) = @_;

    my $filename = $input->{filename};

    return unless $filename =~ m!^lib/(.+)\.pm$!;
    my $package = $1;
    $package =~ s!/!::!g;
    return unless $package =~ /\AAcme::CPANModules::/;
    $self->_process_module($document, $input, $package);
}

1;
# ABSTRACT: Plugin to use when building Acme::CPANModules::* distribution

=for Pod::Coverage weave_section

=head1 SYNOPSIS

In your F<weaver.ini>:

 [-Acme::CPANModules]


=head1 DESCRIPTION

This plugin is used when building Acme::CPANModules::* distributions. It
currently does the following:

=over

=item * Create "MODULES INCLUDED IN THIS ACME::CPANMODULES MODULE" POD section from the list

=item * Mention some modules in See Also section

e.g. L<Acme::CPANModules> (the convention/standard), L<cpanmodules> (the CLI
tool), etc.

=back


=head1 SEE ALSO

L<Acme::CPANModules>

L<Dist::Zilla::Plugin::Acme::CPANModules>
