use t::Helper;

plan skip_all => 'Live tests skipped. Set REDIS_TEST_DATABASE to "default" for db #14 on localhost or a redis:// url for custom.' unless $ENV{REDIS_TEST_DATABASE};

my $server = $t->app->redis->subscribe('convos:user:fooman:magnet');
my ($form, $tmp);

$form = {login => 'foobar', password => 'barbar'};

$t->post_ok('/login' => form => $form)->status_is('401', 'failed to log in');

# invalid register is tested in landing-page.t

$form = {login => 'fooman', email => 'foobar@barbar.com', password => 'barbar', password_again => 'barbar',};
$t->post_ok('/register' => form => $form)
  ->status_is('302', 'first user gets to be admin')
  ->header_like('Location', qr{/wizard$}, 'Redirect to settings page');

$t->get_ok($t->tx->res->headers->location)
  ->text_is('title', 'Testing - Add connection')
  ->element_exists('form[action="/settings/connection"][method="post"]')
  ->element_exists('select[name="name"]')
  ->element_exists('select[name="name"] option[value="efnet"]')
  ->element_exists('input[name="nick"][id="nick"]')
  ->element_exists('select[name="channels"][id="channels"]')
  ->element_exists('option[value="#convos"]')
  ->text_is('button[name="action"][value="save"]', 'Start chatting')
  ;

$form = { wizard => 1 };
$t->post_ok('/settings/connection', form => $form)
  ->element_exists('div.name > .error')
  ->element_exists_not('div.avatar > .error')
  ->element_exists('select[name="name"] option[value="magnet"]')
  ->element_exists('input[name="nick"][value]')
  ->element_exists('select[name="channels"]')
  ;

$form = { wizard => 1, name => 'freenode', nick => 'ice_cool', channels => ', #way #cool ,,,',};
$t->post_ok('/settings/connection', form => $form)
  ->status_is('302')
  ->header_like('Location', qr{/convos$}, 'Redirect back to settings page')
  ;

is redis_do([rpop => 'core:control']), 'start:fooman:freenode', 'start connection';

$t->get_ok($t->tx->res->headers->location)
  ->text_is('title', 'Testing - Chat')
  ->element_exists('div.messages ul li')
  ->element_exists('div.messages ul li:first-child img[src="/avatar/convos@loopback"]')
  ->text_is('div.messages ul li:first-child h3 a', 'convos')
  ->text_is('div.messages ul li:first-child div', 'Hi fooman!')
  ;

done_testing;