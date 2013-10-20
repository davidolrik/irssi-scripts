use 5.10.1;
use Module::Build;

my $class = Module::Build->subclass(
    class => "Module::Build::Custom",
    code => <<'SUBCLASS' );
use 5.10.1;
use File::Copy;

sub ACTION_install {
    my $self = shift;

    if ( -d "$ENV{HOME}/.irssi/scripts" ) {
        foreach my $filename ( <./script/*.pl> ) {
            copy($filename, "$ENV{HOME}/.irssi/scripts") or die "Copy failed: $!";
        }
    }
    else {
        die "Personal Irssi script directory found at $ENV{HOME}/.irssi/scripts";
    }
    $self->SUPER::ACTION_install;
}
SUBCLASS

$class->new(
    module_name     => 'irssi-scripts',
    dist_abstract   => 'Test',
    dist_author     => 'David Olrik <david@olrik.dk>',
    dist_version    => '0.1',
    license         => 'perl',
    requires        => {
        'perl'            => '5.10.1',
        'Mojolicious'     => '4.49',
        'DateTime'        => '1.03',
        'Net::Jabber'     => '2.0',
        'Unicode::String' => '2.09',

    },
    create_packlist => 0,
)->create_build_script;
