use Mojo::DOM;
# use Mojo::UserAgent;
use strict;
use warnings;
my $content = qq|
<html>
 <table>
   <tr class="balls">
            <td>1</td> 
                <td>2</td> 
                                    <td>3</td>
   </tr>
   <tr class="walls"><td>test</td>
 </table>
</html>
|;
my $dom = Mojo::DOM->new($content);
print $dom->find('tr[class="balls"]  td')->map('text')->join(","),"\n";
$dom->find('tr[class="balls"]  td')->last->append('<td>4</td>');
print $dom;


 
# Fine grained response handling (dies on connection errors)
# my $ua  = Mojo::UserAgent->new;
# my $res = $ua->get('docs.mojolicious.org')->result;
# if    ($res->is_success)  { say $res->body }
# elsif ($res->is_error)    { say $res->message }
# elsif ($res->code == 301) { say $res->headers->location }
# else                      { say 'Whatever...' }

#  'https://australia.national-lottery.com/saturday-lotto/past-results'   
#  -H 'authority: australia.national-lottery.com'   -H 'cache-control: max-age=0'   -H 'sec-ch-ua: "Google Chrome";v="95", "Chromium";v="95", ";Not A Brand";v="99"'   -H 'sec-ch-ua-mobile: ?0'   -H 'sec-ch-ua-platform: "Linux"'   -H 'dnt: 1'   -H 'upgrade-insecure-requests: 1'   -H 'user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.54 Safari/537.36'   -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9'   -H 'sec-fetch-site: none'   -H 'sec-fetch-mode: navigate'   -H 'sec-fetch-user: ?1'   -H 'sec-fetch-dest: document'   -H 'accept-language: en-GB,en-US;q=0.9,en;q=0.8'   -H 'cookie: _ga=GA1.2.801274161.1634863985; setLocation=SaturdayLotto; _gid=GA1.2.844685380.1634973477'   -H 'if-modified-since: Sat, 16 Oct 2021 11:46:32 BST'





# print $ua->get('blogs.perl.org')->result->dom->find('li class => "entry-body"')->map('text')->join("\n");

#$ua->get('blogs.perl.org')->result->dom->find('h2 > a')->map('text')->join("\n");
