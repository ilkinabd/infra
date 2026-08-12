import os
import sys

def main():
    # Strictly require .env in the root directory
    if not os.path.exists('.env'):
        print('❌ Error: .env file does not exist in root directory!')
        sys.exit(1)
        
    print('⚙️ Parsing environment variables and compiling configurations...')
    
    # Read root .env
    with open('.env', 'r') as f:
        lines = f.readlines()
        
    api_lines = []
    admin_lines = []
    report_lines = []
    front_lines = []
    
    # Extract variables into a dictionary for easy configuration reads
    env = {}
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if '=' not in line:
            continue
        key, val = line.split('=', 1)
        env[key.strip()] = val.strip()
        
        # Populate target environment file lines
        if line.startswith('API_'):
            api_lines.append(line[4:])
        elif line.startswith('ADMIN_'):
            admin_lines.append(line[6:])
        elif line.startswith('REPORT_'):
            report_lines.append(line[7:])
        elif line.startswith('FRONT_'):
            front_lines.append(line[6:])
            
    # Ensure folder exists
    os.makedirs('production/enviroment', exist_ok=True)
    
    # Write environment files
    with open('production/enviroment/api.env', 'w') as f:
        f.write('\n'.join(api_lines) + '\n')
    with open('production/enviroment/admin.env', 'w') as f:
        f.write('\n'.join(admin_lines) + '\n')
    with open('production/enviroment/report.env', 'w') as f:
        f.write('\n'.join(report_lines) + '\n')
    with open('production/enviroment/front.env', 'w') as f:
        f.write('\n'.join(front_lines) + '\n')
        
    # Compile Nginx config template
    template_path = 'production/nginx/conf.d/default.conf.template'
    output_path = 'production/nginx/conf.d/default.conf'
    
    services = {
        'FRONT': {
            'domain': env.get('FRONT_DOMAIN', 'lobbym.com'),
            'protocol': env.get('FRONT_PROTOCOL', 'https')
        },
        'API': {
            'domain': env.get('API_DOMAIN', 'api.lobbym.com'),
            'protocol': env.get('API_PROTOCOL', 'https')
        },
        'ADMIN': {
            'domain': env.get('ADMIN_DOMAIN', 'admin.lobbym.com'),
            'protocol': env.get('ADMIN_PROTOCOL', 'https')
        },
        'REPORT': {
            'domain': env.get('REPORT_DOMAIN', 'report.lobbym.com'),
            'protocol': env.get('REPORT_PROTOCOL', 'https')
        },
        'SOCKET': {
            'domain': env.get('SOCKET_DOMAIN', 'socket.lobbym.com'),
            'protocol': env.get('SOCKET_PROTOCOL', 'https')
        }
    }
    
    if os.path.exists(template_path):
        # Build redirect block for HTTPS domains
        redirect_domains = []
        for name, cfg in services.items():
            if cfg['protocol'] == 'https':
                redirect_domains.append(cfg['domain'])
                # If frontend is on a root domain, also redirect the www subdomain
                if name == 'FRONT':
                    redirect_domains.append(f"www.{cfg['domain']}")
                    
        if redirect_domains:
            domain_list = ' '.join(redirect_domains)
            redirect_block = (
                f"server {{\n"
                f"    listen 80;\n"
                f"    server_name {domain_list};\n"
                f"    return 301 https://$host$request_uri;\n"
                f"}}"
            )
        else:
            redirect_block = ""
            
        with open(template_path, 'r') as f:
            template = f.read()
            
        # Replace global redirect block
        template = template.replace('__REDIRECT_BLOCK__', redirect_block)
        
        # Replace placeholders for each service
        for name, cfg in services.items():
            domain = cfg['domain']
            protocol = cfg['protocol']
            
            if protocol == 'https':
                listen_port = "443 ssl"
                ssl_config = (
                    f"    ssl_certificate /certs/fullchain.pem;\n"
                    f"    ssl_certificate_key /certs/privkey.pem;"
                )
            else:
                listen_port = "80"
                ssl_config = ""
                
            # If it is the frontend service, add www alias
            if name == 'FRONT':
                template = template.replace('__FRONT_DOMAIN__', f"{domain} www.{domain}")
            else:
                template = template.replace(f'__{name}_DOMAIN__', domain)
                
            template = template.replace(f'__{name}_LISTEN_PORT__', listen_port)
            template = template.replace(f'__{name}_SSL_CONFIG__', ssl_config)
            
        with open(output_path, 'w') as f:
            f.write(template)
            
        print('✓ Compiled Nginx reverse proxy configuration.')

    # Compile Docker Compose template
    compose_template = 'production/docker-compose.yml.template'
    compose_output = 'production/docker-compose.yml'
    
    if os.path.exists(compose_template):
        with open(compose_template, 'r') as f:
            template = f.read()
            
        template = template.replace('__FRONT_DOMAIN__', services['FRONT']['domain'])
        template = template.replace('__API_DOMAIN__', services['API']['domain'])
        template = template.replace('__ADMIN_DOMAIN__', services['ADMIN']['domain'])
        template = template.replace('__REPORT_DOMAIN__', services['REPORT']['domain'])
        template = template.replace('__SOCKET_DOMAIN__', services['SOCKET']['domain'])
        
        with open(compose_output, 'w') as f:
            f.write(template)
            
        print('✓ Compiled production docker-compose configuration.')

if __name__ == '__main__':
    main()
