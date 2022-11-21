
#!/usr/bin/3

from brownie import Blit, accounts, Tarma

def main():
    acct = accounts.load('testac')

    # # ERC 20
    # return Blit.deploy({'from': acct}, publish_source=True)

    # # Tarma ERC 1155
    return Tarma.deploy('0xDa4872F00A64A0093E06B25490e548AFa0a074c5', {'from': acct}, publish_source=True)

    # To update source on existing ERC20:
    # token = Token.at("0xe3e15d3215bb52e594dF4eb4aFF8Cc444CAf2A96")
    # Token.publish_source(token)
